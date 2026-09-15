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

# The panel, in the three styles it draws: a strip along the edge, a floating
# bar, islands. panel.qml renders two thinner ones under those, which say
# nothing a reader of the README needs, so the picture stops after three.
#
# The one picture not here is the taskbar's window previews. Its cards are
# pictures of windows, a picture of a window needs a compositor, and offscreen
# there is none -- so it renders as a row of application icons, which is the
# honest fallback and the wrong advertisement. That one is taken on a real
# screen, against windows opened for the purpose, and cropped to the card.
if wanted panel; then
    echo "==> panel"
    PREVIEW_DEMO=1 bash "$HERE/preview.sh" "$HERE/panel.qml" "$OUT/panel.png" 1400 320 light >/dev/null
    magick "$OUT/panel.png" -crop 1400x290+0+10 +repage "$OUT/panel.png"
    echo "    $OUT/panel.png"
fi

PREVIEW_WIDGET=status \
    shot quick-settings "$HERE/popout.qml" "$OUT/quick-settings.png" 560 800 light 3000

PREVIEW_PAGE=appearance \
    shot settings "$HERE/settings.qml" "$OUT/settings.png" 1280 820 light 3500

# The notification centre's own feed is empty until something arrives, so the
# target seeds a plausible one -- see PREVIEW_NOTES in popout.qml. Made up,
# and deliberately: a real one is somebody's messages.
PREVIEW_WIDGET=notifications PREVIEW_NOTES=1 \
    shot notifications "$HERE/popout.qml" "$OUT/notifications.png" 640 700 light 3000

# The start menu. Its pinned applications, its recent files, what is playing
# and what the machine is doing are all somebody's, so all four are replaced --
# see PREVIEW_DEMO in preview.sh, and the pins below, which are KDE's own
# applications because those are the ones a reader of a KDE project will have.
PREVIEW_WIDGET=launcher \
PREVIEW_RUNTIME='{"launcher.pinned":["org.kde.dolphin","org.kde.konsole","org.kde.kate","org.kde.kcalc","systemsettings","org.kde.gwenview"]}' \
    shot launcher "$HERE/popout.qml" "$OUT/launcher.png" 1020 760 light 3200

# Alt+Tab. Not preview.sh's to render: the switcher is a KWin package rather
# than part of the shell, so it has a harness of its own -- which also holds
# the five invented windows it is drawn against.
#
# The crop is fixed because the picture is: the same five windows, the same
# layout, the same stage every time. Change the model in switcher.sh and this
# wants looking at again.
if wanted switcher; then
    echo "==> switcher"
    SWITCHER_SHOT="$OUT/switcher.png" bash "$HERE/switcher.sh" row >/dev/null
    magick "$OUT/switcher.png" -crop 1146x334+282+114 +repage "$OUT/switcher.png"
    echo "    $OUT/switcher.png"
fi

echo
echo "done. The README links these by path; nothing else needs changing."
