// A label that opens and closes what is under it: "Details", "Advanced".
// Only the header; what it opens is the page's, shown while `open` is.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Row {
    id: root

    property string label: ""
    property bool open: false

    spacing: 4

    Glyph {
        anchors.verticalCenter: parent.verticalCenter
        name: root.open ? "expand_more" : "chevron_right"
        fallback: root.open ? "arrow-down" : "arrow-right"
        size: 18
        color: Theme.mut
    }

    PanelText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.pixelSize: 12
        color: Theme.mut
    }

    TapHandler { onTapped: root.open = !root.open }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
