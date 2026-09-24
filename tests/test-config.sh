#!/usr/bin/env bash
# Reading the effective configuration: defaults, with the profile on top.
#
# The case these exist for: a setting that is OFF. jq's `//` takes its
# right-hand side when the left is false as well as null, so every boolean
# turned off read back as its default -- which is to say, as on. A setting
# whose whole purpose is to turn something off cannot be read that way.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/scripts/lib/config.sh"

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

# Every command that changes a setting writes it through config_set: into the
# active profile, only the one path, and by a rename beside the file the shell
# is watching -- never a truncate in place, never a copy in from /tmp.
echo "== one setting written into the profile =="
write_profile '{ "panel": { "thickness": 44 }, "keep": "me" }'
config_set_string '.panel.renderer' plasma; rc=$?
check "written"                    "$rc:$(jq -c '.panel' "$profile")"         '0:{"thickness":44,"renderer":"plasma"}'
check "and nothing else touched"   "$(jq -r '.keep' "$profile")"                "me"
config_set '.osd.enabled' false
check "JSON goes in as JSON"       "$(jq -c '.osd' "$profile")"                 '{"enabled":false}'
check "and reads back"             "$(config_get '.osd.enabled' true)"          "false"
TMPDIR=/nonexistent config_set '.panel.thickness' 50; rc=$?
check "not by way of /tmp"         "$rc:$(jq -r '.panel.thickness' "$profile")" "0:50"
check "and nothing left beside it" "$(ls -A "$(dirname "$profile")" | grep -vx shell.json | wc -l)" "0"

printf '{"profile": "other"}\n' > "$CONFIG_DIR/state.json"
config_set_string '.panel.position' left
check "into the active profile"    "$(jq -r '.panel.position' "$CONFIG_DIR/profiles/other/shell.json")" "left"
check "not the default one"        "$(jq -r '.panel.position // "untouched"' "$profile")" "untouched"
rm -f "$CONFIG_DIR/state.json"

write_profile '{ this is not json'
config_set_string '.panel.renderer' plasma; rc=$?
check "a broken profile says so"   "$rc" "2"
check "and is left exactly as it was" "$(cat "$profile")" '{ this is not json'

harness_done
