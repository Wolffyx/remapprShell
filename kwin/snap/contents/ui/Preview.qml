/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Where the window would go: the zone under the pointer, or under the
    keyboard's choice, drawn at its size on the screen. Both of the script's
    windows draw one, over the area they cover.

    KWin's own outline would be the thing to draw, and Workspace.showOutline
    draws it -- but KWin takes it down again at every step of a drag that is
    not over one of its own snapping edges, so it never shows here. This is
    drawn like the panel's lit zone instead.
*/
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: preview

    // The zone in the screen's pixels, or null for none.
    property var target: null
    // The area the window holding this covers, in the screen's pixels.
    property rect area

    readonly property color accent: Kirigami.Theme.highlightColor

    visible: opacity > 0
    opacity: preview.target ? 1 : 0
    x: preview.target ? preview.target.x - preview.area.x + 6 : preview.x
    y: preview.target ? preview.target.y - preview.area.y + 6 : preview.y
    width: preview.target ? preview.target.width - 12 : preview.width
    height: preview.target ? preview.target.height - 12 : preview.height
    radius: 12
    color: Qt.rgba(preview.accent.r, preview.accent.g, preview.accent.b, 0.22)
    border.width: 2
    border.color: Qt.rgba(preview.accent.r, preview.accent.g, preview.accent.b, 0.85)

    Behavior on opacity {
        NumberAnimation { duration: 110 }
    }
    Behavior on x {
        enabled: preview.opacity > 0
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: preview.opacity > 0
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }
    Behavior on width {
        enabled: preview.opacity > 0
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        enabled: preview.opacity > 0
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }
}
