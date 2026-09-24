pragma ComponentBehavior: Bound

// A row on a quick settings page -- a network or a device: what it is, how it
// is, and a mark at the end.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: item

    property string glyph: ""
    property string title: ""
    property string sub: ""
    property string mark: ""
    property bool current: false
    signal activated

    width: parent ? parent.width : 0
    height: 52
    radius: Theme.radiusOf(14)
    color: item.current ? Theme.accC : (itemHover.hovered ? Theme.s2 : "transparent")

    Glyph {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        name: item.glyph
        size: 20
        color: item.current ? Theme.acc : Theme.mut
    }

    Column {
        x: 44
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 44 - 40

        PanelText {
            width: parent.width
            elide: Text.ElideRight
            text: item.title
            font.pixelSize: 14
            color: item.current ? Theme.accCFg : Theme.fg
        }

        PanelText {
            visible: item.sub.length > 0
            width: parent.width
            elide: Text.ElideRight
            text: item.sub
            font.pixelSize: 12
            color: item.current ? Theme.alpha(Theme.accCFg, 0.75) : Theme.mut
        }
    }

    Glyph {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        visible: item.mark.length > 0
        name: item.mark
        size: 18
        color: item.current ? Theme.acc : Theme.mut
    }

    HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: item.activated() }
}
