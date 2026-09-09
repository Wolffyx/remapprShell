// The frame every setting shares: label, description, control, and a way back
// to the default.
//
// Having one row type is what keeps a settings page from drifting into a
// collection of subtly different layouts.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

Item {
    id: root

    required property string label
    property string description: ""

    // Shown only when the user has changed this from the shipped default,
    // which is also the answer to "what have I actually customised?".
    property bool overridden: false
    signal resetRequested

    default property alias control: controlSlot.data

    implicitHeight: Math.max(text.implicitHeight, controlSlot.implicitHeight) + 16

    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 12

        Column {
            id: text
            width: parent.width - controlSlot.width - resetButton.width - parent.spacing * 2
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            PanelText {
                text: root.label
                font.pixelSize: 13
            }

            PanelText {
                visible: root.description.length > 0
                text: root.description
                width: parent.width
                wrapMode: Text.WordWrap
                font.pixelSize: 11
                color: PlasmaColors.foregroundInactive
            }
        }

        Item {
            id: resetButton
            width: root.overridden ? 22 : 0
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            visible: root.overridden

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: resetHover.hovered ? PlasmaColors.hoverBackground : "transparent"

                PanelIcon {
                    anchors.centerIn: parent
                    implicitSize: 14
                    iconName: "edit-undo"
                }

                HoverHandler { id: resetHover }
                TapHandler { onTapped: root.resetRequested() }
            }
        }

        Item {
            id: controlSlot
            width: Math.min(200, parent.width * 0.4)
            implicitHeight: childrenRect.height
            height: implicitHeight
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
