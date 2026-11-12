// The clipboard card, offscreen, with a history made up for the picture:
// the wide card with its preview, and the narrow one beside it.
//
//   dev/preview/preview.sh dev/preview/clipboard.qml out.png 1260 600 dark
//
// PREVIEW_INDEX moves the selection.

import QtQuick
import Quickshell
import qs.domain.status
import qs.domain.theme
import qs.ui.clipboard

Stage {
    id: stage
    middle: false

    readonly property real now: Date.now()
    readonly property string picture: "/usr/share/wallpapers/cachyos-wallpapers/Abstract.png"

    Component.onCompleted: {
        const min = 60000;
        ClipboardStatus.ownEntries = [
            { text: "make test", image: false, time: stage.now - 20000 },
            { text: "https://doc.qt.io/qt-6/qml-qtquick-keys.html", image: false, time: stage.now - min },
            { text: "", image: true, path: stage.picture, width: 3840, height: 2160, time: stage.now - 4 * min },
            { text: "#466fbd", image: false, pinned: true, time: stage.now - 9 * min },
            { text: "Keys.onUpPressed: win.move(-1)\nKeys.onDownPressed: win.move(1)\nKeys.onReturnPressed: win.choose(win.index)",
              image: false, time: stage.now - 12 * min },
            { text: "~/Projects/shell/widgets/clipboard/Widget.qml", image: false, time: stage.now - 18 * min },
            { text: "Group windows by application", image: false, time: stage.now - 26 * min },
            { text: "journalctl --user -f", image: false, pinned: true, time: stage.now - 61 * min },
            { text: "2.5 Gbit/s", image: false, time: stage.now - 3 * 60 * min },
            { text: "Meta+V opens the clipboard where the pointer is.", image: false, time: stage.now - 26 * 60 * min }
        ];
    }

    component Framed: Rectangle {
        id: frame
        property alias wide: card.preview
        width: card.implicitWidth + 32
        height: card.implicitHeight + 32
        radius: Theme.radius
        color: Theme.glass
        border.width: 1
        border.color: Theme.out

        ClipboardCard {
            id: card
            anchors.fill: parent
            anchors.margins: 16
            Component.onCompleted: card.index = Number(Quickshell.env("PREVIEW_INDEX") || 0)
        }
    }

    Framed {
        x: 24
        y: 24
        wide: true
    }

    Framed {
        x: 24 + 760 + 24
        y: 24
        wide: false
    }
}
