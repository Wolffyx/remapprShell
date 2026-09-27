#!/usr/bin/env bash
# Tests the KDE config ledger inside a throwaway HOME.
#
# The property that matters: reverting must restore the exact prior state,
# including whether a key existed at all. Restoring an empty value where the
# key was previously absent leaves KDE behaving differently from before.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/scripts/lib/kconfig.sh"

read_key() { kread "$@" 2>/dev/null; }

echo "== a value with a tab or a backslash comes back exactly =="
# A shortcut bound to two keys is stored with a tab between them. Revert used
# to carry values through jq's @tsv, which escaped the tab as a literal "\t"
# that kwriteconfig6 then wrote back as a backslash.
two=$(printf 'none,Alt+Tab\tMeta+Tab,Walk Through Windows')
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key Walk "$two"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key Slash 'Meta+\,none,Back slash'
kconfig_set roundtrip kglobalshortcutsrc kwin Walk "Alt+Tab,none,Walk Through Windows"
kconfig_set roundtrip kglobalshortcutsrc kwin Slash "none,none,Back slash"
kconfig_revert roundtrip >/dev/null 2>&1
check "tab restored as a tab"     "$(read_key kglobalshortcutsrc kwin Walk)" "$two"
check "backslash restored as one" "$(read_key kglobalshortcutsrc kwin Slash)" 'Meta+\,none,Back slash'

# A key that already exists, and one that does not.
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "TheirScheme"

echo "== set =="
kconfig_set theme kdeglobals General ColorScheme "OurScheme"
kconfig_set theme kdeglobals General BrandNewKey "OurValue"
kconfig_set edges kwinrc "Effect-overview" BorderActivate "9"

check "existing key overwritten"     "$(read_key kdeglobals General ColorScheme)" "OurScheme"
check "new key written"              "$(read_key kdeglobals General BrandNewKey)" "OurValue"
check "nested group written"         "$(read_key kwinrc Effect-overview BorderActivate)" "9"

echo "== ledger records the state BEFORE our first write =="
kconfig_set theme kdeglobals General ColorScheme "OurSecondScheme"
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

echo "== scopes are independent =="
# Reverting one feature must not undo another. A single shared ledger made
# `edges revert` also revert the theme, which is not what anyone asked for.
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "Base"
kconfig_set theme kdeglobals General ColorScheme "ThemeValue"
kconfig_set edges kwinrc Windows ElectricBorderTiling "false"

kconfig_revert edges >/dev/null 2>&1
check "edges scope reverted"        "$(read_key kwinrc Windows ElectricBorderTiling)" "<unset>"
check "theme scope left alone"      "$(read_key kdeglobals General ColorScheme)" "ThemeValue"
check "theme record still in ledger" "$(jq '[.entries[] | select(.scope=="theme")] | length' "$(kconfig_ledger)")" "1"
check "edges records dropped"        "$(jq '[.entries[] | select(.scope=="edges")] | length' "$(kconfig_ledger)")" "0"

kconfig_revert theme >/dev/null 2>&1
check "theme scope reverted after"  "$(read_key kdeglobals General ColorScheme)" "Base"
check "ledger empty"                "$(jq '.entries | length' "$(kconfig_ledger)")" "0"


# Removing a whole group.
#
# The ledger can only put back keys we wrote, so a group we create that
# something else later adds a key to survives a revert as an orphan. This is
# the escape hatch for groups whose name is an id we allocated -- and it must
# leave every other group in the file exactly as it was.
echo "== purging a group we own =="

kwriteconfig6 --file purge.rc --group Keep --key mine "yes"
kwriteconfig6 --file purge.rc --group PlasmaViews --group "Panel 811" --key shell "ours"
kwriteconfig6 --file purge.rc --group PlasmaViews --group "Panel 811" --key floating "1"
kwriteconfig6 --file purge.rc --group PlasmaViews --group "Panel 49" --key floating "1"

kconfig_purge_group purge.rc "PlasmaViews/Panel 811"

check "group gone"           "$(grep -c 'Panel 811' "$XDG_CONFIG_HOME/purge.rc")" "0"
check "someone else's key went with it" "$(grep -c '^floating=1$' "$XDG_CONFIG_HOME/purge.rc")" "1"
check "other groups kept"    "$(kreadconfig6 --file purge.rc --group Keep --key mine)" "yes"
check "sibling group kept"   "$(kreadconfig6 --file purge.rc --group PlasmaViews --group "Panel 49" --key floating)" "1"

# Purging what is not there is not an error: revert runs on machines that never
# had the group in the first place.
kconfig_purge_group purge.rc "PlasmaViews/Panel 999"
check "absent group is fine" "$(kreadconfig6 --file purge.rc --group Keep --key mine)" "yes"
kconfig_purge_group nosuchfile.rc "A/B"
check "absent file is fine"  "$?" "0"

harness_done
