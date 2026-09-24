pragma ComponentBehavior: Bound

// A start menu search result: an application, an action or a sum. The one
// selected -- by the arrow keys, or by the pointer resting on it -- is what
// Return runs.

import QtQuick
import qs.domain.launcher.providers
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: result

    required property var modelData
    required property int index
    required property BuiltinProvider provider
    readonly property bool selected: result.index === result.provider.selectedIndex

    width: parent ? parent.width : 0
    height: 52
    radius: Theme.radiusOf(14)
    color: result.selected ? Theme.accC : (resultHover.hovered ? Theme.s2 : "transparent")

    Item {
        id: resultIcon
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26

        PanelIcon {
            anchors.fill: parent
            visible: result.modelData.kind === "app"
            iconName: result.modelData.icon ?? ""
        }

        Glyph {
            anchors.centerIn: parent
            visible: result.modelData.kind !== "app"
            name: result.modelData.glyph ?? ""
            size: 22
            color: result.selected ? Theme.acc : Theme.mut
        }
    }

    Column {
        anchors.left: resultIcon.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter

        PanelText {
            width: parent.width
            elide: Text.ElideRight
            text: result.modelData.name
            font.pixelSize: 14
            font.weight: Font.Medium
            color: result.selected ? Theme.accCFg : Theme.fg
        }

        PanelText {
            visible: text.length > 0
            width: parent.width
            elide: Text.ElideRight
            text: result.modelData.description ?? ""
            font.pixelSize: 12
            color: result.selected ? Theme.alpha(Theme.accCFg, 0.75) : Theme.mut
        }
    }

    HoverHandler {
        id: resultHover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered) result.provider.selectedIndex = result.index
    }
    TapHandler { onTapped: result.provider.activate(result.modelData) }
}
