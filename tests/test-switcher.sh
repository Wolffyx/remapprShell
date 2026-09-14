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

# The switcher's key coming up reaches the shell as its own IPC call. The
# release cannot be left to the surface's key handling: a quick Alt+Tab lets go
# before the surface is mapped, and the switcher was then stuck on screen.
# Meta+Tab: the same question as Alt+Tab, for the other key. The setting says
# who draws it and the key follows, because an overview nobody can open is not
# a choice a person made.
echo "== who draws Meta+Tab =="
sw desktops shell
check "the setting says ours"     "$(jq -r '.switching.desktops' "$CONFIG_DIR/profiles/default/shell.json")" "shell"
check "and it holds Meta+Tab"     "$(sc "$SLUG" overview)" "Meta+Tab,none,Desktops"
check "taken from caelestia"      "$(sc caelestia-shell caelestia-shortcut-overview)" "none,none,Toggle overview"

sw desktops plasma
check "back to KWin's Overview"   "$(jq -r '.switching.desktops' "$CONFIG_DIR/profiles/default/shell.json")" "plasma"
# The fixture below gives KWin's Overview its own default and name, and taking
# a key keeps both -- which is what makes giving it back possible.
check "KWin holds the key"        "$(sc kwin Overview)" "Meta+Tab,Meta+W,Toggle Overview"
check "and ours lost it"          "$(sc "$SLUG" overview)" "none,none,Desktops"
check "a third answer refused"    "$(sw desktops sideways && echo ran || echo refused)" "refused"
sw desktops shell

echo "== show and commit reach the shell =="
cat > "$FAKEBIN/quickshell" <<'STUB'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
    [ "$1" = "call" ] && { shift; printf '%s\n' "$*"; exit 0; }
    shift
done
exit 0
STUB
chmod +x "$FAKEBIN/quickshell"
check "show opens it"            "$("$REPO_ROOT/scripts/switcher.sh" show 2>/dev/null)" "surfaces switcher"
check "and backwards, its own"   "$("$REPO_ROOT/scripts/switcher.sh" show --reverse 2>/dev/null)" "surfaces switcherReverse"
check "the key coming up commits" "$("$REPO_ROOT/scripts/switcher.sh" commit 2>/dev/null)" "surfaces switcherCommit"
check "the overview opens"        "$("$REPO_ROOT/scripts/switcher.sh" overview 2>/dev/null)" "surfaces overview"
check "and backwards"             "$("$REPO_ROOT/scripts/switcher.sh" overview --reverse 2>/dev/null)" "surfaces overviewReverse"
rm -f "$FAKEBIN/quickshell"

# Both switcher keys are held rather than tapped, so the daemon has to run
# something when each is released -- or the fix above reaches only Alt+Tab.
echo "== the daemon runs a release =="
check "switcher releases"         "$(grep -c '"switcher": \[CTL, "switcher", "commit"\]' "$REPO_ROOT/bin/windowsd.py.in")" "1"
check "and so does backwards"     "$(grep -c '"switcher-reverse": \[CTL, "switcher", "commit"\]' "$REPO_ROOT/bin/windowsd.py.in")" "1"
check "it subscribes to releases" "$(grep -c 'globalShortcutReleased' "$REPO_ROOT/bin/windowsd.py.in")" "1"
check "the overview has a key"    "$(grep -c '"overview":  ("Desktops"' "$REPO_ROOT/bin/windowsd.py.in")" "1"
check "and its key releases too"  "$(grep -c '"overview": \[CTL, "switcher", "commit"\]' "$REPO_ROOT/bin/windowsd.py.in")" "1"

echo "== the live session =="
check "no call reached the session" "$(wc -l < "$CALLS")" "0"
env -u "$NO_SESSION_VAR" "$REPO_ROOT/scripts/switcher.sh" revert >/dev/null 2>&1
check "with one, kglobalaccel restarts" "$(grep -c 'restart plasma-kglobalaccel' "$CALLS")" "1"
check "and KWin reloads"                "$(grep -c reconfigure "$CALLS")" "1"

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"
