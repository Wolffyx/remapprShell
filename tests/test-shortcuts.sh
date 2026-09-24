#!/usr/bin/env bash
# Tests global shortcut binding inside a throwaway HOME.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/accel.sh"

# Stand-ins for what reaches the running desktop. Before these, every run of
# this suite restarted the user's own kglobalaccel four times.
CALLS="$SANDBOX/session-calls"
fake_recorders "$CALLS" systemctl kquitapp6 busctl

sc() { "$REPO_ROOT/scripts/shortcuts.sh" "$@" 2>/dev/null; }
# The whole value, so the friendly name and the default are checked too: both
# are what System Settings shows and resets to.
binding() { kread kglobalshortcutsrc "$SLUG" "$1"; }
legacy()  { kread kglobalshortcutsrc services "$SLUG-$1.desktop" _launch; }

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
# Named keys, as Plasma's own defaults spell them. KRunner's first key is
# "Search", and not knowing it once left Meta+Space with KRunner until login.
check "the Search key"        "$(accel_keycode 'Search')"             "16777362"
check "a named key with a space" "$(accel_keycode 'Shift+Volume Up')" "50331762"
check "a named key with a slash" "$(accel_keycode 'Keyboard Light On/Off')" "16777396"
check "the plus key"          "$(accel_keycode 'Meta++')"             "268435499"
check "the tilde"             "$(accel_keycode 'Alt+~')"              "134217854"

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

echo "== the configuration is where the keys live =="
PROFILE="$XDG_CONFIG_HOME/$SLUG/profiles/default/shell.json"
configured() { jq -r --arg a "$1" '.shortcuts[$a] // "<unset>"' "$PROFILE" 2>/dev/null || echo '<no profile>'; }
# Its own starting point: the revert above gave every key back.
sc set search "Meta+J" >/dev/null
sc set settings "Meta+Shift+R" >/dev/null
sc clear launcher >/dev/null
check "set writes the key to the profile"   "$(configured search)" "Meta+J"
check "clear writes none"                   "$(configured launcher)" "none"

# KRunner holding Meta+Space, as it does again after every login.
kwriteconfig6 --file kglobalshortcutsrc --group services --group org.kde.krunner.desktop \
    --key _launch "$(printf 'Search\tAlt+Space\tAlt+F2\tMeta+Space')"
jq '.shortcuts.search = "Meta+Space"' "$PROFILE" > "$PROFILE.tmp" && mv "$PROFILE.tmp" "$PROFILE"
sc sync >/dev/null
check "sync binds what is configured"       "$(binding search)" "Meta+Space,none,Search"
check "and takes it from KRunner"           "$(kreadconfig6 --file kglobalshortcutsrc --group services --group org.kde.krunner.desktop --key _launch)" \
                                            "$(printf 'Search\tAlt+Space\tAlt+F2')"
check "an unbound action stays unbound"     "$(binding launcher)" "none,none,Application menu"
check "a second sync has nothing to do"     "$(sc sync; echo)" ""
out=$("$REPO_ROOT/scripts/shortcuts.sh" sync 2>&1)
check "and says so"                         "$(printf '%s' "$out" | grep -c 'already bound')" "1"

# An empty value is not managed: a key bound in KDE by hand stays.
jq '.shortcuts.settings = ""' "$PROFILE" > "$PROFILE.tmp" && mv "$PROFILE.tmp" "$PROFILE"
sc sync >/dev/null
check "an empty value leaves KDE's key"     "$(binding settings)" "Meta+Shift+R,none,Settings"

echo "== the live session =="
check "nothing reached the session"  "$(wc -l < "$CALLS")" "0"
env -u "$NO_SESSION_VAR" "$REPO_ROOT/scripts/shortcuts.sh" revert >/dev/null 2>&1
# The daemon that owns the component is told first: it re-reads the file, which
# is what makes a revert apply now rather than at the next login.
check "the session daemon is told"   "$(grep -c 'busctl .*Shortcuts Reload' "$CALLS")" "1"
check "and kglobalaccel restarted"   "$(grep -c 'restart plasma-kglobalaccel' "$CALLS")" "1"
check "revert stops enforcing them"  "$(configured search)" ""
check "every action, in one write"   "$(jq -r '[.shortcuts[] | select(. == "")] | length' "$PROFILE")" "${#ACCEL_ACTIONS[@]}"

# The CLI checks a key before writing it and the session daemon registers what
# was written, and each used to keep a table of its own. They disagreed: the
# CLI took "Volume Up" and "Search", wrote them, and the daemon that owns the
# component refused them, so the key grabbed nothing. One table now -- every
# name in it, alone and under modifiers, must be the same integer to both.
echo "== the daemon binds every key the CLI accepts =="
if python3 -c "import gi; gi.require_version('Gio', '2.0')" 2>/dev/null; then
    source "$REPO_ROOT/scripts/lib/render.sh"
    render_template "$REPO_ROOT/bin/windowsd.py.in" "$SANDBOX/windowsd.py"
    specs="$SANDBOX/key-specs"
    {
        while IFS=$'\t' read -r name code; do
            [[ $code =~ ^[0-9]+$ ]] || continue
            printf '%s\n' "$name" "Meta+$name" "Ctrl+Alt+Shift+$name"
        done < "$REPO_ROOT/scripts/lib/keycodes.tsv"
        printf '%s\n' Q q 7 F1 F12 F25 F26 Meta Ctrl Alt Shift Super Meta++ + Meta+Banana Hyper+Q ''
    } | while IFS= read -r spec; do
        printf '%s\t%s\n' "$spec" "$(accel_keycode "$spec" || echo none)"
    done > "$specs"
    agree=$(python3 - "$SANDBOX/windowsd.py" "$specs" <<'PY'
import sys
mod = {}
exec(compile(open(sys.argv[1], encoding="utf-8").read(), "windowsd", "exec"), mod)
bad = []
for line in open(sys.argv[2], encoding="utf-8"):
    spec, want = line.rstrip("\n").split("\t")
    got = mod["keycode"](spec)
    if ("none" if got is None else str(got)) != want:
        bad.append(f"{spec!r}: the CLI says {want}, the daemon {got}")
print("\n".join(bad) or "agree")
PY
)
    check "every key, to both"          "$agree" "agree"
    check "and there were keys to ask"  "$(( $(wc -l < "$specs") > 200 ))" "1"
    check "Volume Up, to the CLI"       "$(accel_keycode 'Volume Up')" "16777330"
    check "the section sign, too"       "$(accel_keycode 'Meta+§')" "268435623"

    # And the actions: the daemon registers, names and runs exactly the ones
    # the CLI binds, in the same order, under the same names.
    daemon_actions=$(python3 - "$SANDBOX/windowsd.py" <<'PY'
import sys
mod = {}
exec(compile(open(sys.argv[1], encoding="utf-8").read(), "windowsd", "exec"), mod)
for action, (label, command) in mod["SHORTCUT_ACTIONS"].items():
    print(f"{action}\t{label}\t{' '.join(command[1:])}")
PY
)
    check "the daemon has the CLI's actions" "$(printf '%s\n' "$daemon_actions" | cut -f1-2)" \
          "$(for a in "${ACCEL_ACTIONS[@]}"; do printf '%s\t%s\n' "$a" "${ACCEL_ACTION_LABEL[$a]}"; done)"
    check "and runs what they ran"      "$(printf '%s\n' "$daemon_actions" | awk -F'\t' '$1 == "switcher-reverse" { print $3 }')" \
          "switcher show --reverse"
else
    echo "  SKIP  python-gobject not installed; the daemon's side was not checked"
fi

harness_done
