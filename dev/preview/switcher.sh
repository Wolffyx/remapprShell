#!/usr/bin/env bash
# Loads the Alt+Tab switcher outside KWin, to see whether it loads at all.
#
# KWin gives a layout one type, TabBoxSwitcher, from its own qrc: qmllint
# cannot resolve it, so a mistake in this file is invisible until Alt+Tab is
# pressed, where it shows up as nothing happening. `Behavior on
# anchors.topMargin` -- a load-time error, since a Behavior cannot attach to a
# member of a grouped property -- got as far as being installed that way.
#
# So: a stub of the one type KWin provides, a model of fake windows, and the
# real file on top. Errors print; "loaded" means it loaded.
#
# It checks that the file loads, not how it looks -- but it can now also take
# a picture, which it could not when this was written. Outside KWin there is
# no platform theme unless one is asked for, so Kirigami.Theme answered white
# on white and a picture said nothing true. QT_QPA_PLATFORMTHEME=kde reads
# kdeglobals the way the real session does, and the colours are the real ones.
#
#   SWITCHER_SHOT=/path/to.png dev/preview/switcher.sh row
#
# What it still cannot show is the window behind it, because the thumbnails
# are KWin's to draw. For that, press Alt+Tab.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WT=$(cd "$HERE/../.." && pwd)

root=$(mktemp -d "$HERE/switcher.XXXX")
trap 'rm -rf "$root"' EXIT

mkdir -p "$root/org/kde/kwin"
cat > "$root/org/kde/kwin/qmldir" <<'QMLDIR'
module org.kde.kwin
TabBoxSwitcher 1.0 TabBoxSwitcher.qml
WindowThumbnail 1.0 WindowThumbnail.qml
QMLDIR

cat > "$root/org/kde/kwin/WindowThumbnail.qml" <<'THUMB'
import QtQuick

// KWin renders the real window here. Outside KWin there is nothing to render,
// and the point of this stub is that the file still loads.
Item { property var wId }
THUMB

cat > "$root/org/kde/kwin/TabBoxSwitcher.qml" <<'STUB'
import QtQuick

// An Item, not a Window. KWin's own type is a window, and a window loaded
// inside a Loader draws in a window of its own rather than on the stage --
// which is why the picture was an empty gradient the first time it was tried.
// As an Item the switcher draws where it is put, and can be grabbed.
//
// `visible` is Item's already, so it is not redeclared here: doing so is an
// error, and the error is reported against this stub rather than against the
// file under test.
Item {
    anchors.fill: parent ? parent : undefined
    property var model: fake
    property int currentIndex: 1
    property rect screenGeometry: Qt.rect(0, 0, 2560, 1440)

    readonly property ListModel fake: ListModel {
        ListElement { caption: "shell.json — WebStorm";       icon: "code-context";        minimized: false; windowId: 1 }
        ListElement { caption: "Quickshell docs — Firefox";   icon: "firefox";             minimized: false; windowId: 2 }
        ListElement { caption: "~ : fish — Konsole";          icon: "utilities-terminal";  minimized: false; windowId: 3 }
        ListElement { caption: "Wallpapers — Dolphin";        icon: "system-file-manager"; minimized: true;  windowId: 4 }
        ListElement { caption: "Remappr Shell settings";      icon: "configure";           minimized: false; windowId: 5 }
    }
    function activate(i) { }
}
STUB

cat > "$root/preview.qml" <<HARNESS
import QtQuick
import QtQuick.Window
import "."

Window {
    visible: true
    width: 1700; height: 560
    color: "#00000000"

    // The switcher draws itself over whatever is behind it, and behind it
    // here is nothing. A plain field rather than transparency, so the shadow
    // and the card's own edge have something to sit on.
    Rectangle {
        id: stage
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#c8d5ef" }
            GradientStop { position: 0.5; color: "#e6dcd2" }
            GradientStop { position: 1; color: "#f2d7c4" }
        }

        Loader {
            id: load
            anchors.fill: parent
            source: Qt.resolvedUrl("main.qml")
            onStatusChanged: {
                if (status === Loader.Error) { console.warn("switcher: FAILED to load"); Qt.exit(1); }
                if (status === Loader.Ready) console.warn("switcher: loaded");
            }
        }
    }

    readonly property string shot: "${SWITCHER_SHOT:-}"

    Timer {
        interval: 1200; running: true
        onTriggered: {
            if (shot.length === 0) {
                Qt.exit(0);
                return;
            }
            stage.grabToImage(r => { r.saveToFile(shot); console.warn("switcher: wrote " + shot); Qt.exit(0); });
        }
    }
}
HARNESS

# The layout is a template now -- one source, three packages -- so each one is
# rendered and loaded in turn. A layout that fails to load is Alt+Tab doing
# nothing, and nothing else here can tell you that.
source "$WT/scripts/lib/log.sh"
source "$WT/scripts/lib/brand.sh"
source "$WT/scripts/lib/render.sh"


for layout in ${1:-row grid icons}; do
    echo "== $layout =="
    SWITCHER_LAYOUT=$layout SWITCHER_SUFFIX="" SWITCHER_LABEL="" \
        render_template "$WT/theme/windowswitcher/contents/ui/main.qml.in" "$root/main.qml" \
        || { echo "switcher: could not render $layout"; exit 1; }

    # For a picture only: the switcher's contents live in a PlasmaCore.Dialog,
    # which is a window of its own, and a window is not part of any grab taken
    # of the stage -- which is why the first picture of this was an empty
    # gradient. The dialog becomes a plain Item so the same contents draw where
    # they are put.
    #
    # What is lost with it is the dialog's own background, which is Plasma's
    # rather than this file's. A rectangle of Kirigami.Theme.backgroundColor
    # stands in for it, with the margin Plasma's dialog puts around a mainItem
    # -- without that the footer row draws outside the panel, which looks like
    # a layout fault in the file and is not one. So the picture is
    # the real cards, the real layout and the real colours, on a stand-in for
    # the surface under them. Everything a reader would look at is the file's.
    if [ -n "${SWITCHER_SHOT:-}" ]; then
        sed -i -E 's/^    PlasmaCore\.Dialog \{/    Item {/;
            /^        location: PlasmaCore\.Types\.Floating$/d;
            /^        visible: tabBox\.visible$/d;
            /^        flags: Qt\.Popup/d;
            /^        x: tabBox\.screenGeometry/d;
            /^        y: tabBox\.screenGeometry/d;
            s/^        mainItem: Item \{/        anchors.centerIn: parent\n        width: content.implicitWidth + tabBox.pad\n        height: content.implicitHeight + tabBox.pad\n\n        Rectangle {\n            anchors.fill: parent\n            radius: tabBox.radius\n            color: Kirigami.Theme.backgroundColor\n        }\n\n        Item {/' \
            "$root/main.qml"
    fi

    # /usr/bin/qml is Qt5's and answers "Did not load any objects" whatever it
    # is given, exactly as /usr/bin/qmllint is Qt5's. Use Qt6's.
    env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen \
        QT_QPA_PLATFORMTHEME=kde XDG_CURRENT_DESKTOP=KDE QT_FORCE_STDERR_LOGGING=1 \
        timeout 30 /usr/lib/qt6/bin/qml -I "$root" "$root/preview.qml" 2>&1 \
      | grep -viE 'KWindowShadow|installEventFilter|platform plugin|propertyCache|support raise' \
      | grep -vE '^\s*$' | head -20
done
