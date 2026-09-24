/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The kiosk style's staff sign-in, in the corner rather than the centre:
    this lock's own password field, for the account that locked it, and
    whose that is -- with the machine's status, the hint, and whatever went
    wrong.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: staff

    required property var ui

    // The frame's scale, and the one "Larger text" enlarges reading type by.
    property real unit: 1
    property real textUnit: 1

    // The page's colours, which the style sets.
    required property color ink
    required property color sub
    required property color card
    required property color hair
    required property color accent

    // The field, for the style to hand to the frame.
    readonly property LockPrompt field: password

    height: staffColumn.height + Math.round(48 * staff.unit)
    radius: Math.round(22 * staff.unit)
    color: staff.card
    border.width: 1
    border.color: staff.hair

    Column {
        id: staffColumn

        x: Math.round(24 * staff.unit)
        y: Math.round(24 * staff.unit)
        width: staff.width - 2 * x
        spacing: Math.round(14 * staff.unit)

        Item {
            width: parent.width
            height: Math.max(staffTitle.height, status.height)

            Column {
                id: staffTitle

                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(3 * staff.unit)

                Text {
                    text: "Staff sign-in"
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(17 * staff.textUnit)
                    font.weight: Font.Medium
                    color: staff.ink
                }

                // Whose session a right password opens.
                Text {
                    text: "Unlocks " + staff.ui.userName + "’s session"
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(13 * staff.textUnit)
                    color: staff.sub
                }
            }

            LockStatus {
                id: status

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                ui: staff.ui
                ink: staff.sub
                warn: "#8a5a20"
                textSize: Math.round(12 * staff.textUnit)
                spacing: Math.round(10 * staff.unit)
            }
        }

        LockPrompt {
            id: password

            width: parent.width
            height: Math.round(52 * staff.textUnit)
            unlock: staff.ui.unlock
            unit: staff.textUnit
            glyph: "password"
            showButton: false
            radius: Math.round(12 * staff.unit)
            ink: staff.ink
            dim: staff.sub
            accent: staff.accent
            fieldColor: "#f5f1ea"
            fieldBorder: staff.accent
        }

        // The hint, then whatever went wrong. Close together, so that an
        // empty message costs the card next to nothing.
        Column {
            width: parent.width
            spacing: Math.round(6 * staff.unit)

            Text {
                width: parent.width
                text: staff.ui.unlock.resting ? "too many attempts · wait a moment" : "password · enter ⏎"
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: Math.round(13 * staff.textUnit)
                color: staff.sub
            }

            LockMessage {
                width: parent.width
                unlock: staff.ui.unlock
                unit: staff.textUnit
                align: Text.AlignLeft
                ink: staff.ink
                warn: "#8a5a20"
            }
        }
    }
}
