pragma ComponentBehavior: Bound

// An application in the start menu as a tile: its icon on a tinted square,
// its name under. Clicking it starts the application.

import QtQuick
import qs.domain.launcher.providers
import qs.domain.theme
import qs.ui.primitives

Item {
    id: tile

    required property var modelData
    required property BuiltinProvider provider
    property bool framed: true

    width: 96
    height: 100

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusOf(16)
        color: tileHover.hovered ? Theme.s2 : "transparent"
    }

    Rectangle {
        id: square
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        width: 52
        height: 52
        radius: Theme.radiusOf(16)
        color: tile.framed ? Theme.accC : "transparent"

        PanelIcon {
            anchors.centerIn: parent
            implicitSize: tile.framed ? 30 : 40
            iconName: tile.modelData.icon ?? ""
        }
    }

    PanelText {
        anchors.top: square.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 8
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: tile.modelData.name
        font.pixelSize: 12
    }

    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.provider.launch(tile.modelData) }
}
