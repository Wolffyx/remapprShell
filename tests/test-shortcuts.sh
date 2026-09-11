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

# Stand-ins for what reaches the running desktop. Before these, every run of
# this suite restarted the user's own kglobalaccel four times.
FAKEBIN="$SANDBOX/bin"; mkdir -p "$FAKEBIN"
CALLS="$SANDBOX/session-calls"; : > "$CALLS"
for t in systemctl kquitapp6; do
    printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "%s"\n' "$t" "$CALLS" > "$FAKEBIN/$t"
    chmod +x "$FAKEBIN/$t"
done
export PATH="$FAKEBIN:$PATH"
export "$NO_SESSION_VAR=1"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }
sc() { "$REPO_ROOT/scripts/shortcuts.sh" "$@" 2>/dev/null; }
binding() { kreadconfig6 --file kglobalshortcutsrc --group services --group "$SLUG-$1.desktop" --key _launch --default '<unset>'; }

mkdir -p "$APPLICATIONS_DIR"
for a in launcher search settings; do : > "$APPLICATIONS_DIR/$SLUG-$a.desktop"; done
: > "$XDG_CONFIG_HOME/kglobalshortcutsrc"

# Something else already owns a key, exactly as caelestia owns Meta here.
kwriteconfig6 --file kglobalshortcutsrc --group someothershell --key take-over "Meta,none,Theirs"

echo "== set =="
sc set settings "Meta+Shift+R" >/dev/null
# A desktop file's launch shortcut is the key alone, as Plasma writes every
# other one; the three-field form belongs to components' actions.
check "binding written as the key alone" "$(binding settings)" "Meta+Shift+R"
check "rejects unknown action" "$(sc set nosuchaction Meta+X >/dev/null && echo ran || echo refused)" "refused"

echo "== a key someone holds is taken from them, and named =="
out=$("$REPO_ROOT/scripts/shortcuts.sh" set launcher "Meta" 2>&1)
check "names the holder"                "$(printf '%s' "$out" | grep -c 'taken from someothershell: Theirs')" "1"
check "binds when asked"                "$(binding launcher)" "Meta"
check "the holder no longer has it"     "$(kreadconfig6 --file kglobalshortcutsrc --group someothershell --key take-over)" "none,none,Theirs"

echo "== a key held second in a list is found =="
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Some Action" "$(printf 'Meta+Q\tMeta+J,none,Some Action')"
sc set search "Meta+J" >/dev/null
check "only that key is taken"          "$(kreadconfig6 --file kglobalshortcutsrc --group kwin --key 'Some Action')" "Meta+Q,none,Some Action"

echo "== clear =="
sc clear launcher >/dev/null
check "cleared to none" "$(binding launcher)" "none"

echo "== revert =="
sc revert >/dev/null
check "settings binding removed"  "$(binding settings)" "<unset>"
check "launcher binding removed"  "$(binding launcher)" "<unset>"
check "the holder's key given back" "$(kreadconfig6 --file kglobalshortcutsrc --group someothershell --key take-over)" "Meta,none,Theirs"
check "the second holder's too"     "$(kreadconfig6 --file kglobalshortcutsrc --group kwin --key 'Some Action')" "$(printf 'Meta+Q\tMeta+J,none,Some Action')"

echo "== the live session =="
check "kglobalaccel never restarted" "$(wc -l < "$CALLS")" "0"
env -u "$NO_SESSION_VAR" "$REPO_ROOT/scripts/shortcuts.sh" revert >/dev/null 2>&1
check "with one, it is"              "$(grep -c 'restart plasma-kglobalaccel' "$CALLS")" "1"

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"
