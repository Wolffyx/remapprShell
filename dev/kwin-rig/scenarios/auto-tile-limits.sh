# Auto-tiling against KWin's smallest tile, and its three settings:
#   dev/kwin-rig/run.sh scenarios/auto-tile-limits.sh
#
# KWin 6.8 makes no tile under 0.15 of the screen a side: asked to, it made a
# 288 px tile and four of none, and the fifth window on stayed where it had
# opened. Eight windows now take eight tiles, none of them smaller; Max
# floats the windows past it until a tiled one goes; Layout=master puts one
# on the left and the rest in a column; Ratio is a share.

untiled() { local n c=0; for n in "$@"; do [ "$(tile "$n")" = none ] && c=$((c + 1)); done; echo "$c"; }
smallest() {
    local n w h min=99999
    for n in "$@"; do
        IFS=, read -r _ _ w h <<< "$(tile "$n")"
        [ -n "$h" ] && [ "$w" -lt "$min" ] && min=$w
        [ -n "$h" ] && [ "$h" -lt "$min" ] && min=$h
    done
    echo "$min"
}

for n in a b c d e f g h; do window $n 500 300 steelblue; done
load kwin/tile
sleep 0.5
check "eight windows, eight tiles" "$(untiled a b c d e f g h)" "0"
check "none under KWin's 0.15 of 1080" "$([ "$(smallest a b c d e f g h)" -ge 162 ] && echo yes || echo no)" "yes"

load kwin/tile Max=3
sleep 0.5
check "Max=3: five float" "$(untiled a b c d e f g h)" "5"
kill "$(pgrep -f "$RUN/a.qml" | head -1)"; sleep 1.2
check "one tiled closes: a waiting one takes its place" "$(untiled b c d e f g h)" "4"

load kwin/tile Max=0 Layout=master Ratio=60
sleep 0.5
master=$(for n in b c d e f g h; do t=$(tile $n); [ "${t%%,*}" = 0 ] && echo "$n"; done)
check "master: one window on the left" "$(echo "$master" | wc -l)" "1"
check "at 60% of the width" "$(tile "$master" | cut -d, -f3)" "1152"
check "a column of six beside the master: every one tiled" "$(untiled b c d e f g h)" "0"
