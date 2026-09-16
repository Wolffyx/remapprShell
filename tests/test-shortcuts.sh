#!/usr/bin/env bash
# Tests global shortcut binding inside a throwaway HOME.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/accel.sh"

# Stand-ins for what reaches the running desktop. Before these, every run of
# this suite restarted the user's own kglobalaccel four times.
FAKEBIN="$SANDBOX/bin"; mkdir -p "$FAKEBIN"
CALLS="$SANDBOX/session-calls"; : > "$CALLS"
for t in systemctl kquitapp6 busctl; do
    printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "%s"\n' "$t" "$CALLS" > "$FAKEBIN/$t"
    chmod +x "$FAKEBIN/$t"
done
export PATH="$FAKEBIN:$PATH"
export "$NO_SESSION_VAR=1"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }
sc() { "$REPO_ROOT/scripts/shortcuts.sh" "$@" 2>/dev/null; }
# The whole value, so the friendly name and the default are checked too: both
# are what System Settings shows and resets to.
binding() { kreadconfig6 --file kglobalshortcutsrc --group "$SLUG" --key "$1" --default '<unset>'; }
legacy()  { kreadconfig6 --file kglobalshortcutsrc --group services --group "$SLUG-$1.desktop" --key _launch --default '<unset>'; }

mkdir -p "$APPLICATIONS_DIR"
for a in launcher search settings; do : > "$APPLICATIONS_DIR/$SLUG-$a.desktop"; done
: > "$XDG_CONFIG_HOME/kglobalshortcutsrc"

# Something else already owns a key, exactly as caelestia owns Meta here.
kwriteconfig6 --file kglobalshortcutsrc --group someothershell --key take-over "Meta,none,Theirs"

echo "== set =="
sc set settings "Meta+Shift+R" >/dev/null
# A component's action is "keys,default,friendly". The friendly name is what
# System Settings lists, so it is the sentence rather than the id.
check "binding written as a component action" "$(binding settings)" "Meta+Shift+R,none,Settings"
check "rejects unknown action" "$(sc set nosuchaction Meta+X >/dev/null && echo ran || echo refused)" "refused"

echo "== a key someone holds is taken from them, and named =="
out=$("$REPO_ROOT/scripts/shortcuts.sh" set launcher "Meta" 2>&1)
check "names the holder"                "$(printf '%s' "$out" | grep -c 'taken from someothershell: Theirs')" "1"
check "binds when asked"                "$(binding launcher)" "Meta,none,Application menu"
check "the holder no longer has it"     "$(kreadconfig6 --file kglobalshortcutsrc --group someothershell --key take-over)" "none,none,Theirs"

echo "== a key held second in a list is found =="
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Some Action" "$(printf 'Meta+Q\tMeta+J,none,Some Action')"
sc set search "Meta+J" >/dev/null
check "only that key is taken"          "$(kreadconfig6 --file kglobalshortcutsrc --group kwin --key 'Some Action')" "Meta+Q,none,Some Action"

echo "== clear =="
sc clear launcher >/dev/null
check "cleared to none, keeping its name" "$(binding launcher)" "none,none,Application menu"

# The form this project used before: a desktop file's launch shortcut, which
# kglobalaccel reads only when it starts and therefore never grabs when it is
# added afterwards.
echo "== migrate =="
kwriteconfig6 --file kglobalshortcutsrc --group services --group "$SLUG-sidebar.desktop" --key _launch "Meta+S"
kwriteconfig6 --file kglobalshortcutsrc --group services --group "$SLUG-keys.desktop" --key _launch "Meta+K"
sc set keys "Meta+Shift+K" >/dev/null
sc migrate >/dev/null
check "an old binding is moved"      "$(binding sidebar)" "Meta+S,none,Sidebar"
check "the old group is gone"        "$(legacy sidebar)"  "<unset>"
check "one already moved is kept"    "$(binding keys)"    "Meta+Shift+K,none,Keyboard shortcuts"
check "and its old group goes too"   "$(legacy keys)"     "<unset>"
sc clear sidebar >/dev/null
sc clear keys >/dev/null

echo "== revert =="
sc revert >/dev/null
check "settings binding removed"  "$(binding settings)" "<unset>"
check "launcher binding removed"  "$(binding launcher)" "<unset>"
check "the switcher was never touched" "$(binding switcher)" "<unset>"
check "the holder's key given back" "$(kreadconfig6 --file kglobalshortcutsrc --group someothershell --key take-over)" "Meta,none,Theirs"
check "the second holder's too"     "$(kreadconfig6 --file kglobalshortcutsrc --group kwin --key 'Some Action')" "$(printf 'Meta+Q\tMeta+J,none,Some Action')"

# The numbers a running kglobalaccel actually holds. All three were read back
# off the server on 2026-09-13 after setting them, so these are not derived
# from the same table twice.
echo "== keys as Qt encodes them =="
check "Print"                 "$(accel_keycode 'Print')"              "16777225"
check "Meta+Shift+Print"      "$(accel_keycode 'Meta+Shift+Print')"   "318767113"
check "Meta+Print"            "$(accel_keycode 'Meta+Print')"         "285212681"
check "a letter is its ASCII" "$(accel_keycode 'Q')"                  "81"
check "lower case too"        "$(accel_keycode 'q')"                  "81"
check "Meta+Space"            "$(accel_keycode 'Meta+Space')"         "268435488"
check "a function key"        "$(accel_keycode 'F5')"                 "16777268"
check "the last function key" "$(accel_keycode 'F12')"                "16777275"
check "Alt+Tab"               "$(accel_keycode 'Alt+Tab')"            "150994945"
check "every modifier at once" "$(accel_keycode 'Meta+Alt+Ctrl+Shift+Delete')" "520093703"

# Refusing is the point: a key this table gets wrong would be bound to the
# wrong thing silently, where a refusal falls back to applying at next login.
# A bare Super key opening a launcher is a real binding, and kglobalaccel
# takes it: caelestia had Meta bound that way on this machine.
check "Meta alone is a key"   "$(accel_keycode 'Meta')"               "16777250"
check "and Ctrl alone"        "$(accel_keycode 'Ctrl')"               "16777249"
check "a modifier nobody knows" "$(accel_keycode 'Hyper+Q' || echo refused)"   "refused"
check "nothing at all"        "$(accel_keycode '' || echo refused)"            "refused"
check "a key nobody knows"    "$(accel_keycode 'Meta+Banana' || echo refused)" "refused"

# Punctuation as the file spells it. kglobalshortcutsrc holds what
# QKeySequence prints -- "Meta+/", never "Meta+Slash" -- and this table not
# knowing that is what made `shortcuts set keys "Meta+/"` report success and
# bind nothing.
check "Meta+/"                "$(accel_keycode 'Meta+/')"             "268435503"
check "Meta+Slash, spelled out" "$(accel_keycode 'Meta+Slash')"       "268435503"
check "Meta+,"                "$(accel_keycode 'Meta+,')"             "268435500"
check "Meta+Shift+["          "$(accel_keycode 'Meta+Shift+[')"       "301989979"

echo "== a key that cannot be converted is refused, not reported bound =="
out=$("$REPO_ROOT/scripts/shortcuts.sh" set keys 'Meta+Banana' 2>&1 && echo ran || echo refused)
check "set refuses it"        "$(printf '%s' "$out" | tail -n1)" "refused"
check "and wrote nothing"     "$(binding keys)" "<unset>"
sc set keys 'Meta+/' >/dev/null
check "and takes one it knows" "$(binding keys)" "Meta+/,none,Keyboard shortcuts"
sc clear keys >/dev/null

echo "== the screenshot action =="
sc set screenshot 'Meta+Shift+S' >/dev/null
check "region capture bound"  "$(binding screenshot)" "Meta+Shift+S,none,Screenshot of a region"
check "the script chooses a tool" \
      "$("$REPO_ROOT/scripts/screenshot.sh" status --json 2>/dev/null | jq -r '.modes | length')" "3"
check "an unknown mode is refused" \
      "$("$REPO_ROOT/scripts/screenshot.sh" nonsense >/dev/null 2>&1 && echo ran || echo refused)" "refused"
sc clear screenshot >/dev/null

echo "== the live session =="
check "nothing reached the session"  "$(wc -l < "$CALLS")" "0"
env -u "$NO_SESSION_VAR" "$REPO_ROOT/scripts/shortcuts.sh" revert >/dev/null 2>&1
# The daemon that owns the component is told first: it re-reads the file, which
# is what makes a revert apply now rather than at the next login.
check "the session daemon is told"   "$(grep -c 'busctl .*Shortcuts Reload' "$CALLS")" "1"
check "and kglobalaccel restarted"   "$(grep -c 'restart plasma-kglobalaccel' "$CALLS")" "1"

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"
