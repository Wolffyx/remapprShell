pragma ComponentBehavior: Bound

// A button on the two-pane start menu's rail: in the accent while its view is
// the one showing.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: railButton

    property string glyph: ""
    property bool current: false
    property real glyphSize: railButton.current ? 24 : 22
    signal chosen

    width: 48
    height: 48
    radius: Theme.radiusOf(16)
    color: railButton.current ? Theme.acc : railHover.hovered ? Theme.s3 : "transparent"

    Glyph {
        anchors.centerIn: parent
        name: railButton.glyph
        size: railButton.glyphSize
        color: railButton.current ? Theme.accFg : Theme.mut
    }

    HoverHandler { id: railHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: railButton.chosen() }
}
