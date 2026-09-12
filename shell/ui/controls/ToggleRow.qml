// One switch, with what it does under its name: the design's settings row.
//
// SettingRow is the schema's row and carries a reset button and a description
// that can run to several lines. This is the hand-written pages' version of
// the same thing, sized to the design's rhythm.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

Item {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false
    signal toggled(bool value)

    width: parent ? parent.width : 0
    implicitHeight: Math.max(34, text.implicitHeight)

    Column {
        id: text

        anchors.left: parent.left
        anchors.right: control.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        PanelText {
            width: parent.width
            elide: Text.ElideRight
            text: root.label
            font.pixelSize: 14
            opacity: root.enabled ? 1 : 0.5
        }

        PanelText {
            width: parent.width
            visible: root.description.length > 0
            text: root.description
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            color: Theme.mut
            opacity: root.enabled ? 1 : 0.5
        }
    }

    Toggle {
        id: control
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        enabled: root.enabled
        checked: root.checked
        onToggled: value => root.toggled(value)
    }
}
