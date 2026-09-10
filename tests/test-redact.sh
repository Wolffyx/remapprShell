#!/usr/bin/env bash
# Runs the shell redaction over the shared corpus.
#
# The QML implementation is held to the same file by tests/tst_Redact.qml, so a
# rule changed in one place and not the other fails here or there.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/redact.sh"

FIXTURES="$REPO_ROOT/tests/fixtures/redact-cases.json"
[ -f "$FIXTURES" ] || { echo "missing fixtures: $FIXTURES" >&2; exit 1; }

home=$(jq -r '.home' "$FIXTURES")
user=$(jq -r '.user' "$FIXTURES")
total=$(jq '.cases | length' "$FIXTURES")

pass=0; fail=0
for i in $(seq 0 $((total - 1))); do
    name=$(jq -r ".cases[$i].name" "$FIXTURES")
    got=$(jq -c ".cases[$i].input" "$FIXTURES" | redact_json "$home" "$user" | jq -cS .)
    want=$(jq -cS ".cases[$i].expected" "$FIXTURES")
    if [ "$got" = "$want" ]; then
        printf '  PASS  %s\n' "$name"; pass=$((pass + 1))
    else
        printf '  FAIL  %s\n        want %s\n        got  %s\n' "$name" "$want" "$got" >&2
        fail=$((fail + 1))
    fi
done

# The journal tail is plain text, not JSON, and goes through the same two
# string rules. Kept next to the corpus so both passes are exercised here.
check_text() {
    local name=$1 input=$2 want=$3 got
    got=$(printf '%s\n' "$input" | redact_text "$home" "$user")
    if [ "$got" = "$want" ]; then
        printf '  PASS  %s\n' "$name"; pass=$((pass + 1))
    else
        printf '  FAIL  %s\n        want %q\n        got  %q\n' "$name" "$want" "$got" >&2
        fail=$((fail + 1))
    fi
}

check_text "journal: home path"        "loading /home/testuser/.config/x" "loading ~/.config/x"
check_text "journal: username"         "user testuser logged in"          "user <user> logged in"
check_text "journal: home before user" "/home/testuser/testuser.log"      "~/<user>.log"
check_text "journal: repeated"         "a /home/testuser b /home/testuser" "a ~ b ~"
check_text "journal: nothing to do"    "panel: up on DP-2"                "panel: up on DP-2"

# The corpus is only worth what it covers, so it is checked for the cases the
# plan calls out by name rather than trusted to have kept them.
for required in "window title" "nested" "array"; do
    if ! jq -e --arg r "$required" '[.cases[] | select(.name | test($r; "i"))] | length > 0' "$FIXTURES" >/dev/null; then
        printf '  FAIL  the corpus has no case covering: %s\n' "$required" >&2
        fail=$((fail + 1))
    fi
done

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"
