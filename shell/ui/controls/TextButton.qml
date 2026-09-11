// A button with words on it, for the action a bare icon cannot name.
//
// `checked` marks the current choice in a row of them -- a power profile, say
// -- so a set of alternatives needs no separate control.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

Item {
    id: root

    property string text: ""
    property string iconName: ""
    property bool checked: false
    signal activated

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: 5
        color: root.checked ? PlasmaColors.alpha(PlasmaColors.accent, 0.3)
                            : hover.hovered ? PlasmaColors.hoverBackground
                                            : PlasmaColors.alpha(PlasmaColors.foreground, 0.06)
        border.width: root.checked ? 1 : 0
        border.color: PlasmaColors.accent
        Behavior on color { ColorAnimation { duration: 100 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            PanelIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.iconName.length > 0
                implicitSize: 14
                iconName: root.iconName
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font.pixelSize: 11
            }
        }

        HoverHandler { id: hover }
        TapHandler { onTapped: root.activated() }
    }
}
