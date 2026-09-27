pragma ComponentBehavior: Bound

// The head of a quick settings page: back to the first page, a title, the
// page's own switch.

import QtQuick
import qs.ui.primitives
import qs.ui.controls

Item {
    id: head

    // The status widget, whose `page` going back sets.
    required property var widget

    property string title: ""
    property bool switchable: true
    property bool switchedOn: false
    signal switched(bool on)

    width: parent ? parent.width : 0
    height: 36

    IconButton {
        id: back
        anchors.verticalCenter: parent.verticalCenter
        glyph: "arrow_back"
        iconName: "go-previous"
        onActivated: head.widget.page = "main"
    }

    PanelText {
        anchors.left: back.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: head.title
        font.pixelSize: 16
        font.weight: Font.Medium
    }

    Toggle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: head.switchable
        checked: head.switchedOn
        onToggled: value => head.switched(value)
    }
}
