#!/usr/bin/env bash
# Tests the KDE config ledger inside a throwaway HOME.
#
# The property that matters: reverting must restore the exact prior state,
# including whether a key existed at all. Restoring an empty value where the
# key was previously absent leaves KDE behaving differently from before.
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
source "$REPO_ROOT/scripts/lib/kconfig.sh"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }

read_key() { kreadconfig6 --file "$1" --group "$2" --key "$3" --default "<unset>" 2>/dev/null; }

# A key that already exists, and one that does not.
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "TheirScheme"

echo "== set =="
kconfig_set kdeglobals General ColorScheme "OurScheme"
kconfig_set kdeglobals General BrandNewKey "OurValue"
kconfig_set kwinrc "Effect-overview" BorderActivate "9"

check "existing key overwritten"     "$(read_key kdeglobals General ColorScheme)" "OurScheme"
check "new key written"              "$(read_key kdeglobals General BrandNewKey)" "OurValue"
check "nested group written"         "$(read_key kwinrc Effect-overview BorderActivate)" "9"

echo "== ledger records the state BEFORE our first write =="
kconfig_set kdeglobals General ColorScheme "OurSecondScheme"
check "second write does not overwrite the record" \
      "$(jq -r '[.entries[] | select(.key=="ColorScheme")] | length' "$(kconfig_ledger)")" "1"
check "record holds the original value" \
      "$(jq -r '.entries[] | select(.key=="ColorScheme") | .value' "$(kconfig_ledger)")" "TheirScheme"

echo "== revert =="
kconfig_revert_all

check "pre-existing key restored"    "$(read_key kdeglobals General ColorScheme)" "TheirScheme"
check "key we invented is removed"   "$(read_key kdeglobals General BrandNewKey)" "<unset>"
check "nested group key removed"     "$(read_key kwinrc Effect-overview BorderActivate)" "<unset>"
check "ledger emptied"               "$(jq '.entries | length' "$(kconfig_ledger)")" "0"

echo "== revert is idempotent =="
kconfig_revert_all >/dev/null 2>&1
check "second revert changes nothing" "$(read_key kdeglobals General ColorScheme)" "TheirScheme"

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"
