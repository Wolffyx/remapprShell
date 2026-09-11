#!/usr/bin/env bash
# Tests Alt+Tab and Meta+Tab inside a throwaway HOME.
#
# The shortcuts are seeded the way they were on the machine this was written
# on: caelestia holding both keys, KWin's own switcher unbound.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_DATA_DIRS="$SANDBOX/sys"
# kreadconfig6 falls back to the system's kwinrc for an unset key, and the one
# here names a different Alt+Tab layout from KWin's own default.
export XDG_CONFIG_DIRS="$SANDBOX/etc"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"

FAKEBIN="$SANDBOX/bin"; mkdir -p "$FAKEBIN"
CALLS="$SANDBOX/session-calls"; : > "$CALLS"
for t in qdbus6 busctl systemctl kquitapp6; do
    printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "%s"\n' "$t" "$CALLS" > "$FAKEBIN/$t"
    chmod +x "$FAKEBIN/$t"
done
export PATH="$FAKEBIN:$PATH"
export "$NO_SESSION_VAR=1"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }
sw() { "$REPO_ROOT/scripts/switcher.sh" "$@" >/dev/null 2>&1; }
js() { "$REPO_ROOT/scripts/switcher.sh" status --json 2>/dev/null | jq -r "$1"; }
sc() { kreadconfig6 --file kglobalshortcutsrc --group "$1" --key "$2" --default '<unset>'; }
T=$'\t'

layout() {   # <dir> <id> <name>
    mkdir -p "$1/$2"
    jq -n --arg id "$2" --arg name "$3" '{KPlugin: {Id: $id, Name: $name}}' > "$1/$2/metadata.json"
}
layout "$SANDBOX/sys/kwin/tabbox" big_icons "Large Icons"
layout "$SANDBOX/sys/kwin-wayland/tabbox" thumbnail_grid "Thumbnail Grid"
layout "$XDG_DATA_HOME/kwin/tabbox" mine "Mine"
layout "$XDG_DATA_HOME/kwin/tabbox" big_icons "My Large Icons"

kwriteconfig6 --file kglobalshortcutsrc --group caelestia-shell --key caelestia-shortcut-windowSwitcher "Alt+Tab,none,Open window switcher"
kwriteconfig6 --file kglobalshortcutsrc --group caelestia-shell --key caelestia-shortcut-overview "Meta+Tab,none,Toggle overview"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Walk Through Windows" "none,Alt+Tab${T}Meta+Tab,Walk Through Windows"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Walk Through Windows (Reverse)" "none,Alt+Shift+Tab${T}Meta+Shift+Tab,Walk Through Windows (Reverse)"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Overview" "Meta+W,Meta+W,Toggle Overview"
# A launch shortcut holding Meta+Tab second of two keys, in the key-alone form.
kwriteconfig6 --file kglobalshortcutsrc --group services --group foo.desktop --key _launch "Meta+Q${T}Meta+Tab"
before=$(sha256sum < "$XDG_CONFIG_HOME/kglobalshortcutsrc")

echo "== status =="
check "unset layout reads as KWin's default" "$(js .layout)" "thumbnail_grid"
check "layouts from every data directory"    "$(js '[.layouts[].id] | sort | join(",")')" "big_icons,mine,thumbnail_grid"
check "the user's copy wins a duplicate"     "$(js '.layouts[] | select(.id == "big_icons") | .name')" "My Large Icons"
check "Alt+Tab held by caelestia"            "$(js '.keys[0].holders | map(.group + ":" + .name) | join(",")')" "caelestia-shell:Open window switcher"
check "and not by KWin"                      "$(js .keys[0].kwin)" "false"
check "Meta+Tab held twice, second in a list" "$(js '.keys[1].holders | map(.group) | join(",")')" "caelestia-shell,services/foo.desktop"
check "not customised"                       "$(js .customised)" "false"

echo "== layout =="
sw layout mine
check "layout chosen"            "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName)" "mine"
check "rejects one not installed" "$(sw layout nosuch && echo ran || echo refused)" "refused"

echo "== give alt-tab =="
sw give alt-tab
check "KWin's switcher has Alt+Tab, default kept" "$(sc kwin 'Walk Through Windows')" "Alt+Tab,Alt+Tab${T}Meta+Tab,Walk Through Windows"
check "and the reverse"                          "$(sc kwin 'Walk Through Windows (Reverse)')" "Alt+Shift+Tab,Alt+Shift+Tab${T}Meta+Shift+Tab,Walk Through Windows (Reverse)"
check "caelestia's switcher lost it"             "$(sc caelestia-shell caelestia-shortcut-windowSwitcher)" "none,none,Open window switcher"
check "reads as KWin's"                          "$(js .keys[0].kwin)" "true"
check "rejects an unknown key"                   "$(sw give ctrl-tab && echo ran || echo refused)" "refused"

echo "== give meta-tab =="
sw give meta-tab
check "Overview keeps Meta+W and gains Meta+Tab" "$(sc kwin Overview)" "Meta+W${T}Meta+Tab,Meta+W,Toggle Overview"
check "caelestia's overview lost it"             "$(sc caelestia-shell caelestia-shortcut-overview)" "none,none,Toggle overview"
check "the launch shortcut keeps its other key"  "$(kreadconfig6 --file kglobalshortcutsrc --group services --group foo.desktop --key _launch)" "Meta+Q"
check "customised"                               "$(js .customised)" "true"

echo "== revert =="
sw revert
check "shortcuts byte-identical" "$(sha256sum < "$XDG_CONFIG_HOME/kglobalshortcutsrc")" "$before"
check "layout key removed"       "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName --default '<unset>')" "<unset>"
check "not customised"           "$(js .customised)" "false"

echo "== the live session =="
check "no call reached the session" "$(wc -l < "$CALLS")" "0"
env -u "$NO_SESSION_VAR" "$REPO_ROOT/scripts/switcher.sh" revert >/dev/null 2>&1
check "with one, kglobalaccel restarts" "$(grep -c 'restart plasma-kglobalaccel' "$CALLS")" "1"
check "and KWin reloads"                "$(grep -c reconfigure "$CALLS")" "1"

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"
