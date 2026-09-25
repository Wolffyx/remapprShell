/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The secure style's key panel. Insert, touch, PIN: PAM's steps, said in
    PAM's words -- the key's glyph in a dashed ring, what to do with it, what
    PAM last said, and the way back to the password.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: panel

    required property var ui
    required property SecurePalette colours
    property real unit: 1

    // The key's glyph, and what to do with it.
    property string glyph: ""
    property string ask: ""

    // "Use password instead" was pressed.
    signal passwordChosen

    function px(v: real): int {
        return Math.round(v * panel.unit);
    }

    height: Math.max(ring.height, keyText.height)

    // Clicks here are not for the field hidden underneath.
    MouseArea {
        anchors.fill: parent
        onPressed: panel.ui.focusPassword()
    }

    Item {
        id: ring

        width: panel.px(148)
        height: width
        anchors.verticalCenter: parent.verticalCenter

        Shape {
            anchors.fill: parent

            ShapePath {
                strokeColor: "#3d434a"
                strokeWidth: Math.max(1, panel.px(2))
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 2.4]
                fillColor: "transparent"

                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.width / 2 - panel.px(1)
                    radiusY: ring.height / 2 - panel.px(1)
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        SymbolText {
            anchors.centerIn: parent
            symbol: panel.glyph
            font.pixelSize: panel.px(58)
            color: "#c9ced4"
        }
    }

    Column {
        id: keyText

        anchors.left: ring.right
        anchors.leftMargin: panel.px(36)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: panel.px(8)

        Text {
            width: parent.width
            text: panel.ask
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            font.family: "Rubik"
            font.pixelSize: panel.px(30)
            color: panel.colours.ink
        }

        Text {
            width: parent.width
            text: panel.ui.unlock.message
                || "PAM is waiting for it alongside the password. What it says will appear here."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            lineHeight: 1.3
            font.family: "Rubik"
            font.pixelSize: panel.px(16)
            color: panel.ui.unlock.message ? panel.colours.ink : panel.colours.sub
        }

        Item { width: 1; height: panel.px(14) }

        Rectangle {
            width: useText.implicitWidth + panel.px(44)
            height: panel.px(46)
            radius: panel.px(12)
            color: useHover.hovered ? "#2a2f36" : panel.colours.well

            Text {
                id: useText
                anchors.centerIn: parent
                text: "Use password instead"
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: panel.px(15)
                font.weight: Font.Medium
                color: panel.colours.ink
            }

            HoverHandler { id: useHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: panel.passwordChosen()
            }
            Accessible.role: Accessible.Button
            Accessible.name: "Use password instead"
        }
    }
}
