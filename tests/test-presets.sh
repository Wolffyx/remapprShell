#!/usr/bin/env bash
# Layouts: saving the configuration as one of your own, the list knowing
# which layout is in use, and applying another saving yours to the list first
# when it is in no list yet.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init

preset() { bash "$REPO_ROOT/scripts/preset.sh" "$@"; }
write_profile() { mkdir -p "$(dirname "$profile")"; printf '%s\n' "$1" > "$profile"; }
state() { preset list --json 2>/dev/null | jq -r "$1"; }

# Two shipped layouts, where the installed shell keeps them.
shipped="$DATA_DIR/config/presets"
mkdir -p "$shipped"
printf '%s\n' '{ "name": "Top", "description": "A bar along the top.", "config": { "panel": { "position": "top" } } }' \
    > "$shipped/top.json"
printf '%s\n' '{ "name": "Left", "description": "A bar down the left.", "config": { "panel": { "position": "left" } } }' \
    > "$shipped/left.json"

echo "== the defaults are nothing to save =="
check "no profile: defaults"             "$(state '.state')"                          "defaults"
write_profile '{ "schemaVersion": 3 }'
check "only the version stamp: defaults" "$(state '.state')"                          "defaults"
preset save "Mine" >/dev/null 2>&1
check "saving the defaults is refused"   "$?"                                         "1"
check "and nothing was written" \
    "$([ -d "$CONFIG_DIR/presets" ] && ls "$CONFIG_DIR/presets" | wc -l || echo 0)" "0"

echo "== a shipped layout in use is known by name =="
preset apply top >/dev/null 2>&1
check "applied: saved"                   "$(state '.state')"                          "saved"
check "as top"                           "$(state '.current')"                        "top"
check "and marked in the list"           "$(state '[.layouts[] | select(.current) | .id] | join(",")')" "top"
check "shipped is not the user's"        "$(state '[.layouts[] | select(.custom)] | length')" "0"
preset save "Mine" >/dev/null 2>&1
check "saving a layout already listed is refused" "$?"                               "1"

echo "== a changed configuration is the user's own =="
write_profile '{ "schemaVersion": 3, "panel": { "position": "top", "thickness": 40 } }'
check "changed: custom"                  "$(state '.state')"                          "custom"
check "and no layout is in use"          "$(state '.current')"                        ""
preset save "  My Desk, Evenings! " >/dev/null 2>&1
id=$(state '.current')
check "saved under a name made safe"     "$id"                                        "my-desk-evenings"
file="$CONFIG_DIR/presets/$id.json"
check "named as it was typed, trimmed"   "$(jq -r '.name' "$file")"                   "My Desk, Evenings!"
check "it holds the configuration" \
    "$(jq -c '.config' "$file")"                                                     '{"panel":{"position":"top","thickness":40}}'
check "not the version stamp"            "$(jq -r '.config.schemaVersion // "none"' "$file")" "none"
check "but remembers it"                 "$(jq -r '.schemaVersion' "$file")"          "3"
check "now it is the layout in use"      "$(state '.current')"                        "my-desk-evenings"
check "and it is the user's"             "$(state '[.layouts[] | select(.custom) | .id] | join(",")')" "my-desk-evenings"
contains "the text list has it" "$(preset list 2>/dev/null)" "my-desk-evenings"

echo "== a name already taken gets a number =="
write_profile '{ "schemaVersion": 3, "panel": { "thickness": 30 } }'
preset save "Top" >/dev/null 2>&1
check "a shipped name is not reused"     "$(state '.current')"                        "top-2"
write_profile '{ "schemaVersion": 3, "panel": { "thickness": 31 } }'
preset save "Top" >/dev/null 2>&1
check "nor one of the user's"            "$(state '.current')"                        "top-3"
preset save "   " >/dev/null 2>&1
check "a blank name is refused"          "$?"                                         "1"

echo "== applying another saves an unsaved layout first =="
write_profile '{ "schemaVersion": 3, "panel": { "position": "bottom", "thickness": 64 } }'
before=$(ls "$CONFIG_DIR/presets" | wc -l)
out=$(preset apply left 2>&1)
check "one more layout in the list"      "$(ls "$CONFIG_DIR/presets" | wc -l)"        "$((before + 1))"
saved=$(grep -l '"thickness": 64' "$CONFIG_DIR/presets"/*.json | head -1)
check "it is the one that was replaced" \
    "$(jq -c '.config.panel' "$saved" 2>/dev/null)"                                  '{"position":"bottom","thickness":64}'
contains "and the apply says so"          "$out"                                       "saved to the list first"
check "the new layout is in use"         "$(state '.current')"                        "left"
check "and the profile is still kept as before" \
    "$([ -f "$CONFIG_DIR/profiles/before-left/shell.json" ] && echo yes)"            "yes"

echo "== a layout already listed is not saved twice =="
before=$(ls "$CONFIG_DIR/presets" | wc -l)
preset apply top >/dev/null 2>&1
check "applying from a listed layout adds none" "$(ls "$CONFIG_DIR/presets" | wc -l)" "$before"

echo "== deleting =="
preset delete my-desk-evenings >/dev/null 2>&1
check "the user's own can be deleted"    "$([ -e "$CONFIG_DIR/presets/my-desk-evenings.json" ] && echo yes || echo no)" "no"
preset delete top >/dev/null 2>&1
check "a shipped one cannot"             "$?"                                         "1"
check "and it is still there"            "$([ -f "$shipped/top.json" ] && echo yes)"  "yes"
preset delete "../../profiles/default/shell" >/dev/null 2>&1
check "a path is not a name"             "$?"                                         "1"
check "and the profile is untouched"     "$([ -f "$profile" ] && echo yes)"           "yes"

echo "== a profile that does not parse =="
write_profile '{ "panel": '
check "is unreadable, not custom"        "$(state '.state')"                          "unreadable"
before=$(ls "$CONFIG_DIR/presets" | wc -l)
preset apply left >/dev/null 2>&1
check "and is not saved as a layout"     "$(ls "$CONFIG_DIR/presets" | wc -l)"        "$before"

harness_done
