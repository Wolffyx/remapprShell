/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Console (1b) -- no wallpaper, no glass. A tty-style prompt where
    everything is text and the keys are the whole interface.

    There is no picture to blur and nothing to darken, so both are off and
    the background is the style's own.

    The design's login banner names a kernel and a hostname. The greeter can
    read neither -- it has no session and this file has no way to open /proc --
    so the banner says what is actually known: the account, the screen, and
    what the authenticator has said so far. The F-keys are labelled with the
    three things SessionManagement can really do on this machine, and they are
    bound: a style that printed "F12 poweroff" without binding it would be a
    picture of a console rather than one.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

LockStyle {
    id: console_

    readonly property real unit: console_.ui.unit

    readonly property color ink: "#cdc6be"
    readonly property color mut: "#8a8378"
    readonly property color accent: "#4f60c8"
    readonly property color warn: "#e0c98a"

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: password
    promptBlock: block

    Rectangle {
        anchors.fill: parent
        color: "#0d0c0b"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.31, 0.38, 0.78, 0.16) }
            GradientStop { position: 0.6; color: "transparent" }
        }
    }

    Text {
        x: Math.round(120 * console_.unit)
        y: Math.round(96 * console_.unit)
        text: `${Screen.name} · ${Screen.width}×${Screen.height} · ${clockLine.now.toLocaleString(Qt.locale(), "ddd d MMM HH:mm:ss")}`
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"
        font.pixelSize: Math.round(15 * console_.unit)
        color: console_.mut
    }

    LockClock {
        id: clockLine

        x: console_.width - width - Math.round(120 * console_.unit)
        y: Math.round(88 * console_.unit)
        opacity: console_.ui.showClock ? 1 : 0
        showDate: false
        raised: false
        family: "JetBrains Mono"
        ink: console_.ink
        timeSize: Math.round(76 * console_.unit)
        timeWeight: Font.Medium

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
    }

    // --- the session ------------------------------------------------------

    Item {
        id: block

        x: Math.round(120 * console_.unit)
        y: Math.round(248 * console_.unit)
        width: Math.min(Math.round(1140 * console_.unit), console_.width - 2 * x)
        height: body.height

        Rectangle {
            width: 2
            height: parent.height
            color: console_.accent
        }

        Column {
            id: body

            x: Math.round(34 * console_.unit)
            width: parent.width - x
            spacing: 0

            // The mark, drawn as four cells of a terminal rather than as a
            // logo: the one piece of this style that is not type.
            Row {
                spacing: Math.round(14 * console_.unit)

                Grid {
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 2
                    spacing: Math.round(4 * console_.unit)

                    Repeater {
                        model: [console_.accent, console_.mut, console_.mut, console_.warn]

                        Rectangle {
                            required property color modelData
                            width: Math.round(13 * console_.unit)
                            height: width
                            color: modelData
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "locked session"
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.round(21 * console_.unit)
                    font.weight: Font.Medium
                    color: console_.ink
                }
            }

            Item {
                width: parent.width
                height: Math.round(54 * console_.unit) + login.height

                Text {
                    id: login

                    anchors.bottom: parent.bottom
                    text: "login: "
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.round(24 * console_.unit)
                    color: console_.mut

                    Text {
                        anchors.left: parent.right
                        anchors.baseline: parent.baseline
                        text: console_.ui.userName
                        textFormat: Text.PlainText
                        font: parent.font
                        color: console_.ink
                    }
                }
            }

            Item {
                width: parent.width
                height: password.height + Math.round(22 * console_.unit)

                Text {
                    id: pwLabel

                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(6 * console_.unit)
                    text: "Password: "
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.round(24 * console_.unit)
                    color: console_.mut
                }

                LockPrompt {
                    id: password

                    anchors.left: pwLabel.right
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    unlock: console_.ui.unlock
                    unit: console_.unit
                    chrome: "bare"
                    glyph: ""
                    placeholder: ""
                    showButton: false
                    ink: console_.ink
                    dim: console_.mut
                }
            }

            LockMessage {
                topPadding: Math.round(34 * console_.unit)
                width: parent.width
                unlock: console_.ui.unlock
                unit: console_.unit
                align: Text.AlignLeft
                family: "JetBrains Mono"
                ink: console_.ink
                warn: console_.warn
            }

            Text {
                topPadding: Math.round(14 * console_.unit)
                text: console_.ui.unlock.resting
                    ? "too many attempts · the authenticator is resting"
                    : "type your password, then Enter"
                textFormat: Text.PlainText
                font.family: "JetBrains Mono"
                font.pixelSize: Math.round(17 * console_.unit)
                color: console_.mut
            }

            // The three the greeter can do, as a tty would print them.
            LockActions {
                topPadding: Math.round(56 * console_.unit)
                visible: Options.showSessionButtons
                enabled: console_.ui.unlock.shown
                session: console_.ui.session
                shape: "square"
                unit: console_.unit
                size: Math.round(42 * console_.unit)
                ink: console_.ink
                fill: "transparent"
                stroke: "#2f2b27"
                hot: Qt.rgba(1, 1, 1, 0.06)
            }
        }
    }

    // --- the foot ---------------------------------------------------------

    Item {
        x: Math.round(120 * console_.unit)
        width: console_.width - 2 * x
        height: Math.round(44 * console_.unit)
        y: console_.height - height - Math.round(120 * console_.unit)
        enabled: console_.ui.unlock.shown

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#1e1c1a"
        }

        LockStatus {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            keyboard: console_.ui.keyboard
            ink: console_.ink
            textSize: Math.round(15 * console_.unit)
            onFocusRequested: console_.ui.focusPassword()
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: "pam_unix · the account's own attempt limit applies"
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(15 * console_.unit)
            color: console_.mut
        }
    }
}
