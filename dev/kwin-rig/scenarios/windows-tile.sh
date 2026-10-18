# A tiled window's tile reaches kwin/windows' list: dev/kwin-rig/run.sh scenarios/windows-tile.sh
#
# KWin keeps a tiled window its tile padding short of the tile, and so short
# of a panel's reserved space: a window tiled into the bottom half stopped
# 4 px above it, and the floating panel took it for a window clear of it.
# The shell counts a tiled window by its tile (WindowEvents.reachesEdge);
# this is the proof that the tile is sent, and that it goes when the window
# leaves it.

windows_stub
load kwin/windows
window a 900 600 steelblue
sleep 0.5
check "untiled: no tile sent" "$(tail -1 "$RUN/windows.jsonl" | jq -c '.[] | select(.title=="a") | .tile')" "null"
kjs tiles <<'JS'
const w = workspace.windowList().find(w => w.caption === "a");
const root = workspace.rootTile(w.output, workspace.currentDesktop);
while (root.tiles.length) root.tiles[0].remove();
root.split(2);
const bottom = root.tiles[1];
if (bottom.manage) bottom.manage(w); else w.tile = bottom;
JS
sleep 1
check "tiled bottom: frame" "$(tail -1 "$RUN/windows.jsonl" | jq -c '.[] | select(.title=="a") | [.x,.y,.width,.height]')" "[4,542,1912,534]"
check "tiled bottom: tile sent" "$(tail -1 "$RUN/windows.jsonl" | jq -c '.[] | select(.title=="a") | .tile')" '{"x":0,"y":540,"width":1920,"height":540}'
kjs untile <<'JS'
const w = workspace.windowList().find(w => w.caption === "a");
if (w.tile && w.tile.unmanage) w.tile.unmanage(w); else w.tile = null;
JS
sleep 1
check "untiled again: no tile" "$(tail -1 "$RUN/windows.jsonl" | jq -c '.[] | select(.title=="a") | .tile')" "null"
