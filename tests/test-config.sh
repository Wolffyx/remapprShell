#!/usr/bin/env bash
# Reading the effective configuration: defaults, with the profile on top.
#
# The case these exist for: a setting that is OFF. jq's `//` takes its
# right-hand side when the left is false as well as null, so every boolean
# turned off read back as its default -- which is to say, as on. A setting
# whose whole purpose is to turn something off cannot be read that way.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/config.sh"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }

profile="$CONFIG_DIR/profiles/default/shell.json"
mkdir -p "$(dirname "$profile")"
write_profile() { printf '%s\n' "$1" > "$profile"; }

echo "== a value that is false is false, not its default =="
write_profile '{ "theme": { "desktop": { "enabled": false, "colours": false, "icons": true } } }'
check "false with a true default"  "$(config_get '.theme.desktop.enabled' true)"  "false"
check "and again, nested"          "$(config_get '.theme.desktop.colours' true)"  "false"
check "true is still true"         "$(config_get '.theme.desktop.icons' true)"    "true"

echo "== absent falls back, and only absent =="
check "a key nobody wrote"         "$(config_get '.theme.desktop.nothing' true)"  "true"
check "a whole branch missing"     "$(config_get '.nowhere.at.all' 'fallback')"   "fallback"
check "no default given"           "$(config_get '.nowhere.at.all')"              ""

echo "== the profile sits on top of the shipped defaults =="
write_profile '{ "panel": { "thickness": 44 } }'
check "the profile wins"           "$(config_get '.panel.thickness' 0)"           "44"
check "the rest is the defaults"   "$(config_get '.panel.renderer' 'none')"       "quickshell"

echo "== other shapes =="
write_profile '{ "widgets": { "tray": { "pinned": ["a", "b"] } }, "panel": { "thickness": 0 } }'
check "an array comes back as JSON" "$(config_get '.widgets.tray.pinned' '[]')"   '["a","b"]'
check "zero is a value, not absent" "$(config_get '.panel.thickness' 38)"         "0"

echo "== a profile that does not parse is ignored, as the shell ignores it =="
write_profile '{ this is not json'
check "the defaults are used"      "$(config_get '.panel.renderer' 'none')"       "quickshell"

if [ "$fail" -gt 0 ]; then echo "FAILED: $pass passed, $fail failed" >&2; exit 1; fi
echo "OK: $pass passed"
