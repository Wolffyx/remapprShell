#!/usr/bin/env bash
# The pictures in the README, rendered rather than photographed.
#
# Every one comes from preview.sh: the real components, drawn offscreen from
# this worktree, against a plain gradient. Nothing is mocked up in a design
# tool, so a picture here cannot show something the shell does not do -- and
# when a page changes, re-running this is the whole of updating the README.
#
# PREVIEW_DEMO=1 throughout: a published screenshot must not carry the account
# it was taken on, the network it was taken on, or the hardware it was taken
# with. See preview.sh for what that swaps and why it is only ever names.
#
# The one thing these cannot show is a window: a thumbnail needs a compositor
# and there is none offscreen, so anything window-shaped falls back to an icon.
# Pictures of those are taken on a real screen, by hand, and are not this
# script's to produce.
#
#   dev/preview/readme-shots.sh            # all of them
#   dev/preview/readme-shots.sh panel      # one, by name
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WT=$(cd "$HERE/../.." && pwd)
OUT="$WT/docs/images"
mkdir -p "$OUT"

want=${1:-}
wanted() { [ -z "$want" ] || [ "$want" = "$1" ]; }

shot() {
    local name=$1; shift
    wanted "$name" || return 0
    echo "==> $name"
    PREVIEW_DEMO=1 bash "$HERE/preview.sh" "$@" >/dev/null
    # The stage is a gradient, so -trim finds no border to cut: every picture
    # would carry a different amount of empty sky and they would not sit
    # together on a page. The card is drawn at a known offset instead, so the
    # crop is arithmetic -- see popout.qml, which places it at 40,40.
    magick "$OUT/$name.png" -crop "$(magick "$OUT/$name.png" -format '%wx%h' info:)+0+0" \
        -shave 16x16 +repage "$OUT/$name.png"
    echo "    $OUT/$name.png"
}

# What renders honestly with no compositor behind it: a page, a card, a list.
#
# Not here, and deliberately: the panel itself and the taskbar's window
# previews. Both are mostly the things they are showing -- open windows, live
# thumbnails, a real tray -- and offscreen there are none, so the picture is an
# empty bar and a row of placeholder squares. Those two are taken on a real
# screen and cropped, and are noted as such where they are used.

PREVIEW_WIDGET=status \
    shot quick-settings "$HERE/popout.qml" "$OUT/quick-settings.png" 560 800 light 3000

PREVIEW_PAGE=appearance \
    shot settings "$HERE/settings.qml" "$OUT/settings.png" 1280 820 light 3500

# The notification centre's own feed is empty until something arrives, so the
# target seeds a plausible one -- see PREVIEW_NOTES in popout.qml. Made up,
# and deliberately: a real one is somebody's messages.
PREVIEW_WIDGET=notifications PREVIEW_NOTES=1 \
    shot notifications "$HERE/popout.qml" "$OUT/notifications.png" 640 700 light 3000

echo
echo "done. The README links these by path; nothing else needs changing."
