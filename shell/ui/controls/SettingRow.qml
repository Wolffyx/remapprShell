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

    implicitHeight: Math.max(text.implicitHeight, controlSlot.implicitHeight) + 20

    Row {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 14

        Column {
            id: text
            width: parent.width - controlSlot.width - resetButton.width - parent.spacing * 2
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            PanelText {
                text: root.label
                font.pixelSize: 14
            }

            PanelText {
                visible: root.description.length > 0
                text: root.description
                width: parent.width
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                lineHeight: 1.15
                color: Theme.mut
            }
        }

        Item {
            id: resetButton
            width: root.overridden ? 30 : 0
            height: 30
            anchors.verticalCenter: parent.verticalCenter
            visible: root.overridden

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: resetHover.hovered ? Theme.hover : "transparent"

                Glyph {
                    anchors.centerIn: parent
                    name: "undo"
                    fallback: "edit-undo"
                    size: 18
                    color: Theme.mut
                }

                HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.resetRequested() }
            }
        }

        Item {
            id: controlSlot
            width: Math.min(220, parent.width * 0.4)
            implicitHeight: childrenRect.height
            height: implicitHeight
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
