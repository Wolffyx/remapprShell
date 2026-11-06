pragma ComponentBehavior: Bound

// A snap layout in small, the way the panel draws its cards, with its name
// under it: one of the user's own to edit, or a preset to start one from.

import QtQuick
import qs.domain.theme
import qs.domain.windows.snap
import qs.ui.primitives

Item {
    id: root

    property var tree: SnapEditor.blank()
    property bool tall: false
    property string label: ""
    property bool chosen: false

    signal activated

    readonly property int cardW: root.tall ? 34 : 64
    readonly property int cardH: root.tall ? 60 : 36

    implicitWidth: Math.max(root.cardW + 8, 84)
    implicitHeight: root.cardH + 22

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cardW + 8
        height: root.cardH + 8
        radius: Theme.radiusTiny + 2
        color: hover.hovered || root.chosen ? Theme.accC : Theme.s1
        border.width: root.chosen ? 2 : 1
        border.color: root.chosen ? Theme.acc : Theme.out

        Repeater {
            model: SnapEditor.zones(root.tree)

            delegate: Rectangle {
                required property var modelData

                x: 4 + Math.round(modelData.x * root.cardW) + 1
                y: 4 + Math.round(modelData.y * root.cardH) + 1
                width: Math.round((modelData.x + modelData.width) * root.cardW) - Math.round(modelData.x * root.cardW) - 2
                height: Math.round((modelData.y + modelData.height) * root.cardH) - Math.round(modelData.y * root.cardH) - 2
                radius: 2
                color: Theme.s3
                border.width: 1
                border.color: Theme.out
            }
        }
    }

    PanelText {
        anchors.top: card.bottom
        anchors.topMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.label
        font.pixelSize: 11
        color: Theme.mut
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.activated() }
}
