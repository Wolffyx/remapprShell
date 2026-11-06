# The gap around a tiled window (tileGap): dev/kwin-rig/run.sh scenarios/tile-gap.sh
#
# KWin's tile padding, 4 px by default and kept per screen and desktop. The
# snap script gives its Gap to every root tile when it loads and to a desktop
# added later; a window tiled into the bottom half then reaches the bottom of
# the screen with a gap of 0, where KWin's 4 kept it short.

window a 900 600 steelblue
bottom() {
    kjs tiles <<'JS'
const w = workspace.windowList().find(w => w.caption === "a");
const root = workspace.rootTile(w.output, workspace.currentDesktop);
while (root.tiles.length) root.tiles[0].remove();
root.split(2);
const bottom = root.tiles[1];
if (bottom.manage) bottom.manage(w); else w.tile = bottom;
JS
    sleep 0.8
}
paddings() {
    local tag="PAD$RANDOM"
    kjs pads <<JS
const out = [];
for (const o of workspace.screens) for (const d of workspace.desktops) out.push(workspace.rootTile(o, d).padding);
print("$tag " + out.join(","));
JS
    sleep 0.2
    grep -a "$tag " "$RUN/kwin.log" | tail -1 | sed "s/.*$tag //"
}

bottom
check "KWin's own padding: 4 px short of the tile" "$(geom a | cut -d' ' -f1-4)" "4 542 1912 534"

load kwin/snap Gap=0
check "the snap script gives every root tile its gap" "$(paddings)" "0"
check "and the tiled window fills its tile" "$(geom a | cut -d' ' -f1-4)" "0 540 1920 540"

kjs newdesk <<'JS'
workspace.createDesktop(1, "two");
JS
sleep 0.5
check "a desktop added later gets it too" "$(paddings)" "0,0"

load kwin/snap Gap=12
check "a new gap, at the next load" "$(paddings)" "12,12"
check "the window moves with it" "$(geom a | cut -d' ' -f1-4)" "12 546 1896 522"
