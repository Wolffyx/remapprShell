/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Multi-user (2c) -- a shared machine: pick a seat, then authenticate.

    The seats are real. They come from `SessionsModel`, the same list Plasma's
    own switch-user screen is built from, so a card here is a session that
    actually exists on a VT and tapping it switches to it. The locked account
    keeps the middle card, because that is the one a password unlocks: the
    others are switched to, not unlocked from here, and logind asks them for
    their own password on arrival.

    A machine with one user shows one card. That is not a failure of the
    design -- it is the design telling the truth about the machine.

    The design's bottom bar carries accessibility and language buttons. The
    greeter has no settings window to open and no way to change the language
    mid-lock, so the bar carries what it can actually operate: the on-screen
    keyboard, the keyboard layout, the battery, and the three session actions.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions as Sessions

LockStyle {
    id: seats

    readonly property color ink: "#f4efe8"
    readonly property color mut: "#8a8378"
    readonly property color accent: seats.ui.accent

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: password
    promptBlock: mine

    Sessions.SessionsModel {
        id: sessions
        showNewSessionEntry: false
    }

    Rectangle {
        anchors.fill: parent
        color: "#191715"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(seats.accent, 0.22) }
            GradientStop { position: 0.62; color: "transparent" }
        }
    }

    // --- the clock --------------------------------------------------------

    LockClock {
        id: clock

        x: (seats.width - width) / 2
        y: Math.round(72 * seats.unit)
        centred: true
        raised: false
        showDate: false
        opacity: seats.ui.showClock ? 1 : 0
        ink: seats.ink
        timeSize: Math.round(92 * seats.unit)

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
    }

    Text {
        id: subtitle

        x: (seats.width - width) / 2
        y: Math.round(182 * seats.unit)
        text: clock.now.toLocaleDateString(Qt.locale(), "dddd d MMMM").toUpperCase()
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"
        font.pixelSize: Math.round(16 * seats.unit)
        font.letterSpacing: Math.round(0.6 * seats.unit)
        color: seats.mut
    }

    // --- the seats --------------------------------------------------------

    Row {
        id: row

        x: (seats.width - width) / 2
        // Between the date and the hint above the bar, whether that is one
        // card or four.
        y: Math.max(Math.round(260 * seats.unit),
                    subtitle.y + subtitle.height + Math.round((bar.y - subtitle.y - subtitle.height - height) / 2))
        spacing: Math.round(24 * seats.unit)

        // The other sessions on this machine. Each is a VT to switch to.
        Repeater {
            model: sessions

            Rectangle {
                id: seat

                required property string name
                required property string realName
                required property int vtNumber
                required property bool isTty

                // The locked account has its own card in the middle.
                visible: seat.name !== seats.ui.userName

                width: visible ? Math.round(300 * seats.unit) : 0
                height: Math.round(232 * seats.unit)
                radius: Math.round(26 * seats.unit)
                color: hover.hovered ? "#2a2622" : "#221f1c"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)

                Column {
                    anchors.centerIn: parent
                    spacing: Math.round(20 * seats.unit)

                    LockFace {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(88 * seats.unit)
                        height: width
                        image: ""
                        userName: seat.realName !== "" ? seat.realName : seat.name
                        ink: seats.ink
                        fill: Qt.rgba(1, 1, 1, 0.12)
                        ring: Qt.rgba(1, 1, 1, 0.16)
                        ringWidth: 2
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: seat.realName !== "" ? seat.realName : seat.name
                        textFormat: Text.PlainText
                        font.family: "Rubik"
                        font.pixelSize: Math.round(19 * seats.unit)
                        font.weight: Font.Medium
                        color: seats.ink
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: seat.isTty ? `tty${seat.vtNumber}` : `session on vt${seat.vtNumber}`
                        textFormat: Text.PlainText
                        font.family: "JetBrains Mono"
                        font.pixelSize: Math.round(12.5 * seats.unit)
                        color: seats.mut
                    }
                }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: sessions.switchUser(seat.vtNumber) }
                Accessible.name: `Switch to ${seat.name}`
            }
        }

        // The locked account: the only card with a password in it.
        Rectangle {
            id: mine

            width: Math.round(380 * seats.unit)
            height: Math.round(300 * seats.unit)
            radius: Math.round(26 * seats.unit)
            color: "#2a2622"
            border.width: Math.max(1, Math.round(1.5 * seats.unit))
            border.color: seats.accent

            Column {
                anchors.centerIn: parent
                width: parent.width - Math.round(60 * seats.unit)
                spacing: Math.round(18 * seats.unit)

                LockFace {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(96 * seats.unit)
                    height: width
                    image: seats.ui.userImage
                    userName: seats.ui.userName
                    ink: seats.ink
                    fill: Qt.rgba(1, 1, 1, 0.14)
                    ring: Qt.rgba(1, 1, 1, 0.2)
                    ringWidth: 2
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: seats.ui.userName
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(21 * seats.unit)
                    font.weight: Font.Medium
                    color: seats.ink
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: seats.ui.unlock.resting ? "too many attempts" : "this session · locked"
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.round(12.5 * seats.unit)
                    color: seats.mut
                }

                LockPrompt {
                    id: password

                    width: parent.width
                    height: Math.round(54 * seats.unit)
                    unlock: seats.ui.unlock
                    unit: seats.unit
                    ink: seats.ink
                    dim: seats.mut
                    fieldColor: "#1b1916"
                    fieldBorder: Qt.rgba(1, 1, 1, 0.14)
                }

                LockMessage {
                    width: parent.width
                    unlock: seats.ui.unlock
                    unit: seats.unit
                    ink: seats.ink
                }
            }
        }
    }

    Text {
        x: (seats.width - width) / 2
        y: bar.y - height - Math.round(88 * seats.unit)
        text: sessions.count > 1
            ? "Type to unlock this session · click another seat to switch to it"
            : "Type to unlock"
        textFormat: Text.PlainText
        font.family: "Rubik"
        font.pixelSize: Math.round(13.5 * seats.unit)
        color: seats.mut
        opacity: seats.ui.unlock.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
    }

    // --- the bar ----------------------------------------------------------

    Rectangle {
        id: bar

        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.round(88 * seats.unit)
        color: "#121110"
        enabled: seats.ui.unlock.shown

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        LockStatus {
            anchors.left: parent.left
            anchors.leftMargin: Math.round(64 * seats.unit)
            anchors.verticalCenter: parent.verticalCenter
            keyboard: seats.ui.keyboard
            ink: "#cdc6be"
            textSize: Math.round(13 * seats.unit)
            onFocusRequested: seats.ui.focusPassword()
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Math.round(64 * seats.unit)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(20 * seats.unit)

            MediaCard {
                id: media

                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(300 * seats.unit)
                visible: media.hasPlayer && seats.ui.setting("showMediaControls", true)
                chromeless: true
                textColor: "#cdc6be"
                unit: seats.unit
            }

            LockActions {
                anchors.verticalCenter: parent.verticalCenter
                visible: Options.showSessionButtons
                session: seats.ui.session
                shape: "square"
                unit: seats.unit
                size: Math.round(40 * seats.unit)
                spacing: Math.round(10 * seats.unit)
                ink: "#cdc6be"
                fill: "#1e1c1a"
                stroke: "transparent"
                hot: "#2a2622"
            }
        }
    }
}
