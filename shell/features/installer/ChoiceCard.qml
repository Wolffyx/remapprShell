// One answer to an installer question: a name, what it means, and a mark
// when it is the one chosen. The whole card is the button.
//
// OptionRow's one-line detail was cut off at the window's edge, which is the
// thing this window exists to stop -- kdialog's list did the same to the
// same sentences. Here the detail wraps, and the card is as tall as its text.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: root

    property string title: ""
    property string detail: ""
    property bool selected: false
    signal chosen

    width: parent ? parent.width : 0
    implicitHeight: body.implicitHeight + 24
    radius: Theme.radiusOf(12)
    color: root.selected ? Theme.accC : hover.hovered ? Theme.hover : Theme.s1
    border.width: root.selected ? 0 : 1
    border.color: Theme.outlineVariant
    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    // The radio mark: a ring, filled when chosen.
    Rectangle {
        id: mark
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 9
        color: "transparent"
        border.width: 2
        border.color: root.selected ? Theme.acc : Theme.mut

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: Theme.acc
            visible: root.selected
        }
    }

    Column {
        id: body
        anchors.left: mark.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.title
            font.pixelSize: 14
            font.bold: root.selected
            color: root.selected ? Theme.accCFg : Theme.fg
        }

        PanelText {
            width: parent.width
            visible: root.detail.length > 0
            wrapMode: Text.WordWrap
            text: root.detail
            font.pixelSize: 12
            color: root.selected ? Theme.accCFg : Theme.mut
            opacity: root.selected ? 0.85 : 1
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler { onTapped: root.chosen() }
}
