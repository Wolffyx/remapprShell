pragma ComponentBehavior: Bound

// A tile in quick settings' grid: in the accent while on.
//
// It draws what it is told -- `info`, one of TileGrid's tiles -- and says when
// it was pressed; what pressing it does is the grid's.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: tile

    // { title, sub, glyph, page, on }: see TileGrid.available.
    required property var info

    signal activated

    radius: Theme.radiusOf(20)
    color: tile.info.on ? Theme.acc : (tileHover.hovered ? Theme.s3 : Theme.s2)
    implicitHeight: tileColumn.implicitHeight + 28
    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    readonly property color ink: tile.info.on ? Theme.accFg : Theme.fg

    Column {
        id: tileColumn
        x: 16
        y: 14
        width: parent.width - 32
        spacing: 0

        Item {
            width: parent.width
            height: 24

            Glyph {
                name: tile.info.glyph
                size: 24
                color: tile.ink
            }

            Glyph {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: (tile.info.page ?? "").length > 0
                name: "chevron_right"
                size: 18
                color: tile.ink
                opacity: 0.8
            }
        }

        Item { width: 1; height: 14 }

        PanelText {
            width: parent.width
            elide: Text.ElideRight
            text: tile.info.title
            font.pixelSize: 14
            font.weight: Font.Medium
            color: tile.ink
        }

        PanelText {
            width: parent.width
            elide: Text.ElideRight
            text: tile.info.sub
            font.pixelSize: 12
            color: tile.info.on ? Theme.alpha(Theme.accFg, 0.8) : Theme.mut
        }
    }

    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.activated() }
}
