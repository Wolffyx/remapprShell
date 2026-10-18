pragma ComponentBehavior: Bound

/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Snap Assist, drawn: once a window is snapped into a layout with zones
    still empty, the first empty zone holds the screen's other windows to
    fill it with, and the rest of the empty zones are outlined, so the layout
    being filled can be seen. main.qml decides what is offered, where each is
    drawn (Layouts.grid) and which is chosen; this only draws them.

    Each window is KWin's own picture of it (Thumbnail.qml), or its icon
    where this KWin has no WindowThumbnail to draw one with, and beneath it
    its icon and title.
*/
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: assist

    // Every zone of the layout, in this item's pixels, and for each whether
    // a window is in it.
    property var zones: []
    property var taken: []
    // The zone being filled, and the windows offered for it, most recent
    // first, each drawn in a cell of `cells` (this item's pixels).
    property int target: -1
    property var offered: []
    property var cells: []
    // The window the keyboard or the pointer is on; -1 for none.
    property int selected: -1
    // The height of a cell's title, as Layouts.grid was told it.
    property int label: 28

    readonly property color ink: Kirigami.Theme.textColor
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color surfaceColor: Kirigami.Theme.backgroundColor

    function tint(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    Repeater {
        model: assist.zones

        delegate: Rectangle {
            required property var modelData
            required property int index

            visible: assist.taken[index] !== true && index !== assist.target
            x: modelData.x + 6
            y: modelData.y + 6
            width: modelData.width - 12
            height: modelData.height - 12
            radius: 12
            color: assist.tint(assist.accent, 0.08)
            border.width: 2
            border.color: assist.tint(assist.accent, 0.45)
        }
    }

    Kirigami.ShadowedRectangle {
        readonly property var zone: assist.target >= 0 ? assist.zones[assist.target] : null

        visible: zone !== null
        x: zone ? zone.x + 6 : 0
        y: zone ? zone.y + 6 : 0
        width: zone ? zone.width - 12 : 0
        height: zone ? zone.height - 12 : 0
        radius: 12
        color: assist.tint(assist.surfaceColor, 0.94)
        border.width: 1
        border.color: assist.tint(assist.ink, 0.14)
        shadow.size: 16
        shadow.yOffset: 3
        shadow.color: Qt.rgba(0, 0, 0, 0.28)
    }

    Repeater {
        model: assist.offered

        delegate: Item {
            id: cell

            required property var modelData
            required property int index

            readonly property var box: assist.cells[cell.index] || Qt.rect(0, 0, 0, 0)
            readonly property bool chosen: cell.index === assist.selected

            x: cell.box.x
            y: cell.box.y
            width: cell.box.width
            height: cell.box.height

            Rectangle {
                anchors.fill: parent
                anchors.margins: -6
                radius: 10
                color: cell.chosen ? assist.tint(assist.accent, 0.18) : "transparent"
                border.width: cell.chosen ? 2 : 0
                border.color: assist.accent
            }

            Rectangle {
                id: picture

                width: parent.width
                height: parent.height - assist.label
                radius: 6
                clip: true
                color: Qt.tint(assist.surfaceColor, assist.tint(assist.ink, 0.08))

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.min(64, parent.width / 2, parent.height / 2)
                    height: width
                    source: cell.modelData.icon
                    fallback: "window"
                    visible: thumbnail.status !== Loader.Ready
                }

                Loader {
                    id: thumbnail

                    anchors.fill: parent
                    Component.onCompleted: thumbnail.setSource("Thumbnail.qml", { wId: cell.modelData.internalId })
                }
            }

            // The icon beside the title as well, since a picture KWin
            // cannot draw -- in the rig's software renderer, for one -- is
            // still a loaded thumbnail, and blank.
            Row {
                anchors.top: picture.bottom
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width)
                spacing: 6

                Kirigami.Icon {
                    width: 16
                    height: 16
                    source: cell.modelData.icon
                    fallback: "window"
                }

                Text {
                    width: Math.min(implicitWidth, cell.width - 22)
                    elide: Text.ElideRight
                    text: cell.modelData.caption
                    color: assist.ink
                    font.pixelSize: 13
                }
            }
        }
    }
}
