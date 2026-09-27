#!/usr/bin/env bash
# Tests the CLI's window commands inside a throwaway HOME: KWin's window
# behaviour, and closing a window.
#
# The daemon that holds the window list is tested on its own, in
# tests/test-windowsd*.sh.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init

# KWin's own window behaviour: kwinrc keys, written through the ledger. What
# matters is that a bad value never reaches kwinrc, that a write is recorded
# with what was there before, and that revert puts it back exactly -- an
# unset key deleted again rather than left empty.
echo "== KWin's window behaviour =="
BEHAVE=("$REPO_ROOT/scripts/windows.sh" behaviour)
behave() { env "$NO_SESSION_VAR=1" PATH="$FAKES:$PATH" "${BEHAVE[@]}" "$@" 2>&1; }
kwinrc_key() { kread kwinrc Windows "$1"; }

FAKES="$SANDBOX/fakes"
mkdir -p "$FAKES"
for cmd in qdbus6 busctl systemctl kquitapp6; do
    printf '#!/usr/bin/env bash\necho "$0 $*" >> %s/reached-kde.txt\nexit 0\n' "$SANDBOX" > "$FAKES/$cmd"
    chmod +x "$FAKES/$cmd"
done

check "an unknown setting is refused"    "$(behave set nosuch true >/dev/null 2>&1; echo $?)" "1"
check "a bool takes only true or false"  "$(behave set autoRaise sometimes >/dev/null 2>&1; echo $?)" "1"
check "an enum takes only its values"    "$(behave set focus Whatever >/dev/null 2>&1; echo $?)" "1"
check "a number outside the range"       "$(behave set focusDelay 99999 >/dev/null 2>&1; echo $?)" "1"
check "nothing was written by a refusal" "$(kwinrc_key FocusPolicy)" "<unset>"

behave set focus FocusFollowsMouse >/dev/null
check "focus policy written"             "$(kwinrc_key FocusPolicy)" "FocusFollowsMouse"
behave set borderlessMaximized true >/dev/null
check "borderless maximised written"     "$(kwinrc_key BorderlessMaximizedWindows)" "true"
check "status reads them back"           "$(behave status --json | jq -r '.settings[] | select(.id=="focus") | .value')" "FocusFollowsMouse"
check "and says what the default was"    "$(behave status --json | jq -r '.settings[] | select(.id=="focus") | .default')" "ClickToFocus"
check "the ledger has both"              "$(ledger_count windows-behaviour)" "2"

behave revert >/dev/null
check "revert deletes a key that was unset" "$(kwinrc_key FocusPolicy)" "<unset>"
check "and the other one too"               "$(kwinrc_key BorderlessMaximizedWindows)" "<unset>"
check "the ledger is empty again"           "$(ledger_count windows-behaviour)" "0"
check "nothing reached KDE"                 "$([ -f "$SANDBOX/reached-kde.txt" ] && cat "$SANDBOX/reached-kde.txt" || echo none)" "none"

# Closing a window writes the id into a KWin script's source, so anything
# that is not exactly a uuid must be refused before it gets that far -- and
# with no session, nothing may reach KWin at all.
echo "== closing a window =="
nosession() { env "$NO_SESSION_VAR=1" "$REPO_ROOT/scripts/windows.sh" "$@" 2>&1; }
out=$(nosession close 'a"); workspace.windowList().forEach(w => w.closeWindow()); ("'); status=$?
check "a script in place of an id is refused" "$status:$(printf '%s' "$out" | grep -c 'not a window id')" "1:1"
out=$(nosession close ''); status=$?
check "no id is refused"                      "$status" "1"
out=$(nosession close 1f46c057-675a-4d51-99e5-17aafdfb5b06); status=$?
check "no session, nothing closed"            "$status:$(printf '%s' "$out" | grep -c 'no session')" "1:1"

harness_done
