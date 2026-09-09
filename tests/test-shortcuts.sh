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

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }
sc() { "$REPO_ROOT/scripts/shortcuts.sh" "$@" 2>/dev/null; }
binding() { kreadconfig6 --file kglobalshortcutsrc --group services --group "$SLUG-$1.desktop" --key _launch --default '<unset>'; }

mkdir -p "$APPLICATIONS_DIR"
for a in launcher search settings; do : > "$APPLICATIONS_DIR/$SLUG-$a.desktop"; done

# Something else already owns a key, exactly as caelestia owns Meta here.
kwriteconfig6 --file kglobalshortcutsrc --group someothershell --key take-over "Meta,none,Theirs"

echo "== set =="
sc set settings "Meta+Shift+R" >/dev/null
check "binding written with all three fields" "$(binding settings)" "Meta+Shift+R,none,Settings"
check "rejects unknown action" "$(sc set nosuchaction Meta+X >/dev/null && echo ran || echo refused)" "refused"

echo "== conflicts are reported, not silently taken =="
out=$("$REPO_ROOT/scripts/shortcuts.sh" set launcher "Meta" 2>&1)
check "warns about the existing holder" "$(printf '%s' "$out" | grep -c 'already used by')" "1"
check "still binds when asked"           "$(binding launcher)" "Meta,none,Application menu"

echo "== clear =="
sc clear launcher >/dev/null
check "cleared to none" "$(binding launcher)" "none,none,Application menu"

echo "== revert =="
sc revert >/dev/null
check "settings binding removed"  "$(binding settings)" "<unset>"
check "launcher binding removed"  "$(binding launcher)" "<unset>"
check "other component untouched" "$(kreadconfig6 --file kglobalshortcutsrc --group someothershell --key take-over)" "Meta,none,Theirs"

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"
