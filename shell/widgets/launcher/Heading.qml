pragma ComponentBehavior: Bound

// A heading in the start menu -- "Pinned", "Recent" -- with a link at its end
// where there is somewhere else to go from it.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Item {
    id: heading

    property string text: ""
    property string link: ""
    signal linked

    width: parent ? parent.width : 0
    height: 22

    SectionLabel {
        anchors.verticalCenter: parent.verticalCenter
        text: heading.text
    }

    PanelText {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: heading.link.length > 0
        text: heading.link
        font.pixelSize: 13
        color: Theme.acc

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: heading.linked() }
    }
}
