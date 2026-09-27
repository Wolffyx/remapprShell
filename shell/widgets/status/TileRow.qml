pragma ComponentBehavior: Bound

// A quick settings tile as a row, when dense: its switch at the end, or a
// chevron to its page.
//
// As a Tile, it draws `info` and says when it was pressed.

import QtQuick
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Rectangle {
    id: row

    // As a Tile's.
    required property var info
    readonly property bool paged: (row.info.page ?? "").length > 0

    signal activated

    height: 44
    radius: Theme.radiusOf(14)
    color: row.paged && row.info.on ? Theme.accC : (rowHover.hovered ? Theme.s2 : "transparent")

    Glyph {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        name: row.info.glyph
        size: 20
        color: row.info.on ? Theme.acc : Theme.mut
    }

    PanelText {
        x: 48
        anchors.verticalCenter: parent.verticalCenter
        text: row.info.title
        font.pixelSize: 14
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.paged
            width: Math.min(implicitWidth, 160)
            elide: Text.ElideRight
            text: row.info.sub
            font.pixelSize: 12
            color: Theme.mut
        }

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.paged
            name: "chevron_right"
            size: 18
            color: Theme.mut
        }

        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            visible: !row.paged
            checked: row.info.on
            onToggled: row.activated()
        }
    }

    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: if (row.paged) row.activated() }
}
