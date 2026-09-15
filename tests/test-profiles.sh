#!/usr/bin/env bash
# Keeping a configuration that is about to be replaced.
#
# The case these exist for happened on 2026-09-14 and cost a configuration
# built over days. Two things here replace the active profile wholesale --
# `preset apply` and the wizard's Finish -- and one of them did it with no
# copy kept at all. These pin what "kept" has to mean:
#
#   * a profile, in the configuration directory, because that is the one place
#     a restore point does not roll back;
#   * named for what displaced it, and never overwriting an earlier keep;
#   * carrying the per-output overrides too, which are configuration as much
#     as shell.json is;
#   * and doing nothing, rather than something empty, when there is nothing
#     there yet -- which is every real first run.
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
source "$REPO_ROOT/scripts/lib/profiles.sh"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }

profile="$CONFIG_DIR/profiles/default/shell.json"
write_profile() { mkdir -p "$(dirname "$profile")"; printf '%s\n' "$1" > "$profile"; }

echo "== nothing to keep is not a failure =="
keep_profile before-wizard
check "no profile yet: nothing kept"   "$KEPT_PROFILE"                              ""
check "and no backup either"           "$KEPT_PROFILE_BACKUP"                       ""

write_profile ''
keep_profile before-wizard
check "an empty file: nothing kept"    "$KEPT_PROFILE"                              ""

echo "== what was there becomes a profile =="
write_profile '{ "panel": { "thickness": 52 } }'
keep_profile before-wizard
check "kept under the label"           "$KEPT_PROFILE"                              "before-wizard"
check "the settings came with it" \
    "$(jq -c '.panel.thickness' "$CONFIG_DIR/profiles/before-wizard/shell.json")"   "52"
check "the original is untouched" \
    "$(jq -c '.panel.thickness' "$profile")"                                        "52"

echo "== the copy under state is a second copy, not the copy =="
check "a backup was written too"       "$([ -f "$KEPT_PROFILE_BACKUP" ] && echo yes)" "yes"
check "and it is under the state dir" \
    "$(case "$KEPT_PROFILE_BACKUP" in "$STATE_DIR"/*) echo yes ;; *) echo no ;; esac)" "yes"

echo "== keeping twice does not overwrite the first keep =="
write_profile '{ "panel": { "thickness": 99 } }'
keep_profile before-wizard
check "the second keep is named apart" \
    "$([ "$KEPT_PROFILE" != "before-wizard" ] && echo yes)"                         "yes"
check "it starts with the label" \
    "$(case "$KEPT_PROFILE" in before-wizard-*) echo yes ;; *) echo no ;; esac)"     "yes"
check "the first keep still has the old settings" \
    "$(jq -c '.panel.thickness' "$CONFIG_DIR/profiles/before-wizard/shell.json")"   "52"
check "the second keep has the new ones" \
    "$(jq -c '.panel.thickness' "$CONFIG_DIR/profiles/$KEPT_PROFILE/shell.json")"   "99"

echo "== per-output overrides are configuration too =="
mkdir -p "$CONFIG_DIR/profiles/default/monitors"
printf '{ "panel": { "position": "left" } }\n' > "$CONFIG_DIR/profiles/default/monitors/DP-2.json"
write_profile '{ "panel": { "thickness": 40 } }'
keep_profile before-preset
check "the monitor file came along" \
    "$(jq -c '.panel.position' "$CONFIG_DIR/profiles/before-preset/monitors/DP-2.json")" '"left"'

echo "== a keep is a profile like any other =="
check "profile list shows it" \
    "$(bash "$REPO_ROOT/scripts/profile.sh" list 2>/dev/null | grep -c 'before-preset')" "1"

echo "== the CLI prints the name and nothing else on stdout =="
write_profile '{ "panel": { "thickness": 41 } }'
check "just the name" \
    "$(bash "$REPO_ROOT/scripts/profile.sh" keep from-the-cli 2>/dev/null)"          "from-the-cli"
check "a label with a slash is refused" \
    "$(bash "$REPO_ROOT/scripts/profile.sh" keep ../escape >/dev/null 2>&1; echo $?)" "1"

if [ "$fail" -gt 0 ]; then echo "FAILED: $pass passed, $fail failed" >&2; exit 1; fi
echo "OK: $pass passed"
