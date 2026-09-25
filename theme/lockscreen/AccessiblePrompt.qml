/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The accessible style's way in, down the right: a heading, whose account
    this is, the password in a box with the design's thick border, what went
    wrong or what to do next, the one big Unlock button, and the session's
    actions in words.
*/
pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: prompt

    required property var ui
    required property AccessibleLook look

    // The field, and the button the on-screen keyboard must not cover, for
    // the style to hand to the frame.
    readonly property LockPrompt field: password
    readonly property Item button: unlockButton

    spacing: 0

    Text {
        text: "Unlock this computer"
        textFormat: Text.PlainText
        font.family: "Rubik"
        font.pixelSize: Math.round(34 * prompt.look.s)
        font.weight: Font.Medium
        color: prompt.look.fg
        Accessible.role: Accessible.Heading
        Accessible.name: text
    }

    Item { width: 1; height: Math.round(20 * prompt.look.s) }

    Row {
        spacing: Math.round(16 * prompt.look.s)

        LockFace {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(60 * prompt.look.s)
            height: width
            image: prompt.ui.userImage
            userName: prompt.ui.userName
            ink: prompt.look.fg
            fill: prompt.look.card
            ring: prompt.look.bd
            ringWidth: prompt.look.line
            Accessible.ignored: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: prompt.ui.userName
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: Math.round(22 * prompt.look.s)
            font.weight: Font.Medium
            color: prompt.look.fg
            Accessible.role: Accessible.StaticText
            Accessible.name: "Account: " + prompt.ui.userName
        }
    }

    Item { width: 1; height: Math.round(22 * prompt.look.s) }

    Text {
        text: "Password"
        textFormat: Text.PlainText
        font.family: "Rubik"
        font.pixelSize: Math.round(22 * prompt.look.s)
        color: prompt.look.sub
        Accessible.ignored: true
    }

    Item { width: 1; height: Math.round(10 * prompt.look.s) }

    // The field's box: the design's thick border, in the accent while
    // the field has the keyboard and in the error colour after a refusal.
    Rectangle {
        id: fieldBox

        width: parent.width
        height: Math.round(88 * prompt.look.s)
        radius: Math.round(18 * prompt.look.s)
        color: prompt.look.card
        border.width: prompt.look.thick
        border.color: password.stateBorder

        LockPrompt {
            id: password

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Math.round(26 * prompt.look.s)
            anchors.rightMargin: Math.round(12 * prompt.look.s)
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - 2 * prompt.look.thick
            unlock: prompt.ui.unlock
            unit: 1.5 * prompt.look.s
            chrome: "none"
            glyph: ""
            showButton: false
            placeholder: "Type your password"
            ink: prompt.look.fg
            dim: prompt.look.sub
            accent: prompt.look.acc
            errorColor: prompt.look.err
            restBorder: prompt.look.bd
        }
    }

    Item { width: 1; height: Math.round(14 * prompt.look.s) }

    // Caps Lock, another layout, what PAM said, another reader -- or,
    // with none of those, what to do.
    LockMessage {
        width: parent.width
        unlock: prompt.ui.unlock
        unit: 1.7 * prompt.look.s
        align: Text.AlignLeft
        ink: prompt.ui.unlock.resting ? prompt.look.err : prompt.look.fg
        warn: prompt.look.warn
    }

    Text {
        width: parent.width
        visible: !prompt.ui.unlock.message && !LockKeys.caps && !LockKeys.otherLayout
        text: prompt.ui.unlock.unlockedWithoutPassword
            ? "No password is needed. Press Unlock to continue."
            : "Type your password, then press Enter or Unlock."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        font.family: "Rubik"
        font.pixelSize: Math.round(22 * prompt.look.s)
        color: prompt.look.sub
    }

    Item { width: 1; height: Math.round(18 * prompt.look.s) }

    Rectangle {
        id: unlockButton

        function activate(): void {
            if (prompt.ui.unlock.unlockedWithoutPassword)
                prompt.ui.unlock.confirm();
            else
                password.submit();
        }

        width: parent.width
        height: Math.round(76 * prompt.look.s)
        radius: Math.round(18 * prompt.look.s)
        color: unlockHover.hovered && unlockButton.enabled ? Qt.lighter(prompt.look.acc, 1.08) : prompt.look.acc
        opacity: unlockButton.enabled ? 1 : 0.55
        enabled: !prompt.ui.unlock.resting
        activeFocusOnTab: true

        Row {
            anchors.centerIn: parent
            spacing: Math.round(12 * prompt.look.s)

            SymbolText {
                anchors.verticalCenter: parent.verticalCenter
                symbol: "lock_open"
                font.pixelSize: Math.round(28 * prompt.look.s)
                color: prompt.look.accentFg
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Unlock"
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: Math.round(22 * prompt.look.s)
                font.weight: Font.Medium
                color: prompt.look.accentFg
            }
        }

        AccessibleRing { target: unlockButton; look: prompt.look }

        HoverHandler { id: unlockHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: unlockButton.activate() }
        Keys.onSpacePressed: unlockButton.activate()
        Keys.onReturnPressed: unlockButton.activate()
        Keys.onEnterPressed: unlockButton.activate()

        Accessible.role: Accessible.Button
        Accessible.name: "Unlock"
        Accessible.description: prompt.ui.unlock.unlockedWithoutPassword
            ? "Unlocks the session. No password is needed."
            : "Sends the password and unlocks the session."
        Accessible.focusable: true
        Accessible.onPressAction: unlockButton.activate()
    }

    Item {
        width: 1
        height: Math.round(30 * prompt.look.s)
        visible: actions.visible
    }

    LockActions {
        id: actions
        session: prompt.ui.session
        shape: "text"
        unit: 1.4 * prompt.look.s
        spacing: Math.round(40 * prompt.look.s)
        ink: prompt.look.fg
    }
}
