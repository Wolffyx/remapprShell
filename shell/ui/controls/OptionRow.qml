// One entry in a short list of things to pick from -- a profile, a layout:
// its name, a line about it, and whatever acts on it at the far end.
//
// The profiles and the layouts pages drew the same row by hand. `selected`
// marks the one in use, drawn in `selectedColor` with its text in
// `selectedTextColor`; `hoverable` lights a row that can be acted on as the
// pointer crosses it. Children go at the trailing end, and the text takes
// the rest of the width. The height is the page's to set: the two lists are
// not the same height, and each keeps its own.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

Rectangle {
    id: root

    property string title: ""
    property string detail: ""
    property bool selected: false
    property color selectedColor: Theme.accC
    property color selectedTextColor: Theme.accCFg
    property bool hoverable: false

    default property alias trailing: trail.data

    width: parent ? parent.width : 0
    radius: Theme.radiusOf(12)
    color: root.selected ? root.selectedColor
         : root.hoverable && hover.hovered ? Theme.hover
         : Theme.s1

    Row {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 10

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - trail.width - parent.spacing
            spacing: 1

            PanelText {
                text: root.title
                font.pixelSize: 14
                color: root.selected ? root.selectedTextColor : Theme.fg
            }

            PanelText {
                width: parent.width
                elide: Text.ElideRight
                text: root.detail
                font.pixelSize: 12
                color: root.selected ? root.selectedTextColor : Theme.mut
                opacity: root.selected ? 0.8 : 1
            }
        }

        Row {
            id: trail
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover
        enabled: root.hoverable
    }
}
