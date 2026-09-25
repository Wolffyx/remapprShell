/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The secure style's password panel: the face and name, the field, what
    went wrong, and a line saying how many passwords this lock has refused
    and who is counting them.
*/
pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: panel

    required property var ui
    required property SecurePalette colours
    property real unit: 1

    // Whether pam_faillock is known to count this account's failures.
    property bool faillock: false

    // Whether the time is said in twelve hours, as the clock is.
    property bool twelveHour: false

    // The field, for the style to hand to the frame.
    readonly property LockPrompt field: password

    // Something was typed: the password is the way in now, whichever tab
    // was up.
    signal typed

    function px(v: real): int {
        return Math.round(v * panel.unit);
    }

    spacing: 0

    Row {
        spacing: panel.px(16)

        LockFace {
            width: panel.px(52)
            height: width
            image: panel.ui.userImage
            userName: panel.ui.userName
            ink: "#3d3a35"
            fill: "#c9c4d8"
            ring: "transparent"
            ringWidth: 0
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: panel.ui.userName
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: panel.px(18)
            font.weight: Font.Medium
            color: panel.colours.ink
        }
    }

    Item { width: 1; height: panel.px(24) }

    LockPrompt {
        id: password

        width: parent.width
        height: panel.px(60)
        unlock: panel.ui.unlock
        unit: panel.unit
        radius: panel.px(14)
        glyph: "password"
        ink: panel.colours.ink
        dim: panel.colours.sub
        accent: panel.ui.accent
        errorColor: panel.colours.bad
        fieldColor: panel.colours.ground
        // In key mode this panel is hidden, so the colour the border has
        // there -- the accent, since the field keeps the keyboard -- is
        // never seen.
        fieldBorder: password.stateBorder

        onTextChanged: {
            if (password.text.length > 0)
                panel.typed();
        }
    }

    Item { width: 1; height: panel.px(12) }

    LockMessage {
        width: parent.width
        unlock: panel.ui.unlock
        unit: panel.unit
        align: Text.AlignLeft
        ink: panel.colours.sub
        warn: panel.colours.warn
    }

    Text {
        readonly property var parts: [
            panel.ui.unlock.refusals > 0
                ? `${panel.ui.unlock.refusals} refused since ${Qt.formatTime(panel.ui.lockedAt, panel.twelveHour ? "h:mm AP" : "HH:mm")}`
                : "enter ⏎ to unlock",
            panel.faillock ? "failures on this account are counted by pam_faillock" : "",
        ].filter(p => p)

        topPadding: panel.px(8)
        width: parent.width
        text: parts.join(" · ")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        font.family: "JetBrains Mono"
        font.pixelSize: panel.px(13)
        color: panel.colours.mut
    }
}
