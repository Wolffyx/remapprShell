/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The day-ahead design's pill, at the foot of the left column: the face,
    the name over one line of state, the password field, and the round
    arrow that sends it.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: pill

    required property var ui
    required property DayAheadPalette colours
    property real unit: 1

    // The field, for the style to hand to the frame.
    readonly property LockPrompt field: password

    function px(v: real): int {
        return Math.round(v * pill.unit);
    }

    height: pill.px(84)
    radius: pill.px(26)
    color: pill.colours.cardFill
    border.width: Math.max(1, pill.px(1.5))
    border.color: password.stateBorder

    // The design's avatar gradient runs at 135 degrees; a circle turned 45
    // turns its gradient without changing its shape.
    Rectangle {
        id: avatar

        x: pill.px(16)
        anchors.verticalCenter: parent.verticalCenter
        width: pill.px(52)
        height: width
        radius: width / 2
        rotation: -45
        gradient: Gradient {
            GradientStop { position: 0; color: "#b9c3e8" }
            GradientStop { position: 1; color: "#e5cdbb" }
        }
    }

    LockFace {
        anchors.fill: avatar
        image: pill.ui.userImage
        userName: pill.ui.userName
        ink: "#3d3a35"
        fill: "transparent"
        ring: "transparent"
        ringWidth: 0
    }

    Column {
        id: who

        anchors.left: avatar.right
        anchors.leftMargin: pill.px(16)
        anchors.verticalCenter: parent.verticalCenter
        width: pill.px(170)
        spacing: pill.px(2)

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: pill.ui.userName
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: pill.px(16)
            font.weight: Font.Medium
            color: pill.colours.ink
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: pill.ui.unlock.resting ? "wait a moment"
                : pill.ui.unlock.refusals > 0 ? pill.ui.unlock.refusals + " refused · try again"
                : "password · enter ⏎"
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: pill.px(12)
            color: pill.ui.unlock.refusals > 0 && !pill.ui.unlock.resting ? pill.colours.bad : pill.colours.sub
        }
    }

    LockPrompt {
        id: password

        anchors.left: who.right
        anchors.leftMargin: pill.px(16)
        anchors.right: go.visible ? go.left : parent.right
        anchors.rightMargin: pill.px(12)
        anchors.verticalCenter: parent.verticalCenter
        unlock: pill.ui.unlock
        unit: pill.unit
        chrome: "none"
        glyph: ""
        placeholder: "Password"
        showButton: false
        ink: pill.colours.ink
        dim: pill.colours.sub
        accent: pill.ui.accent
        errorColor: pill.colours.bad
        alarm: pill.ui.unlock.message.length > 0
    }

    Rectangle {
        id: go

        anchors.right: parent.right
        anchors.rightMargin: pill.px(12)
        anchors.verticalCenter: parent.verticalCenter
        visible: password.takesPassword
        width: pill.px(56)
        height: width
        radius: width / 2
        color: pill.ui.accent
        opacity: pill.ui.unlock.resting ? 0.5 : (goHover.hovered ? 0.88 : 1)

        Text {
            anchors.centerIn: parent
            text: LayoutMirroring.enabled ? "arrow_back" : "arrow_forward"
            font.family: "Material Symbols Rounded"
            font.pixelSize: pill.px(26)
            color: "#ffffff"
        }

        HoverHandler { id: goHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            enabled: !pill.ui.unlock.resting
            onTapped: password.submit()
        }
        Accessible.role: Accessible.Button
        Accessible.name: "Unlock"
    }
}
