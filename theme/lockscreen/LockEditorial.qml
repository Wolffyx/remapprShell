/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Editorial split (1a) -- an opaque ink panel owns the password; the
    wallpaper stays sharp beside it.

    The one style that does not blur: the picture is not a backdrop here, it
    is the left column, and the panel is what keeps the text readable. So the
    frame's blur and its scrim are both off and the darkening is a single
    gradient along the seam.

    The design puts a weather line and a list of notifications down the right
    column. Neither is drawn: the greeter has no forecast and no notification
    history, and a lock screen is the last place to print a plausible-looking
    number. What is there instead is what the greeter does know -- the screen
    it is on, and what PAM will accept.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

LockStyle {
    id: editorial

    readonly property real unit: editorial.ui.unit
    readonly property int panelX: Math.round(editorial.width * 0.615)

    readonly property color ink: "#f4efe8"
    readonly property color dim: "#a89f94"
    readonly property color mut: "#8a8378"
    readonly property color accent: "#4f60c8"
    readonly property color paper: "#2a2521"

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: password
    promptBlock: promptColumn

    // The seam: the wallpaper darkens into the panel rather than stopping
    // against it.
    Rectangle {
        width: editorial.panelX
        height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0.1, 0.09, 0.08, 0.0) }
            GradientStop { position: 0.6; color: Qt.rgba(0.1, 0.09, 0.08, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.1, 0.09, 0.08, 0.38) }
        }
    }

    // What the greeter can say about where it is drawing. Not decoration:
    // it is the one line that tells you which screen you are looking at when
    // a machine has three.
    Column {
        x: Math.round(64 * editorial.unit)
        y: editorial.height - height - Math.round(56 * editorial.unit)
        spacing: Math.round(9 * editorial.unit)
        opacity: editorial.ui.unlock.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        Text {
            text: `${Screen.name} · ${Screen.width}×${Screen.height}`
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(13 * editorial.unit)
            color: "#ffffff"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.45)
        }

        Text {
            text: editorial.ui.unlock.resting ? "too many attempts · wait a moment" : "session locked · type to unlock"
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(13 * editorial.unit)
            color: Qt.rgba(1, 1, 1, 0.78)
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.45)
        }
    }

    // --- the panel -------------------------------------------------------

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: editorial.width - editorial.panelX
        color: "#1a1815"

        Column {
            id: promptColumn

            x: Math.round(80 * editorial.unit)
            width: parent.width - 2 * x
            // Centred, not hung from the top: the design's own column ends in
            // a list of notifications, and without them a top-anchored block
            // left the panel bottom-heavy with nothing in it.
            y: Math.max(Math.round(72 * editorial.unit),
                        Math.round((parent.height - height) / 2) - Math.round(60 * editorial.unit))
            spacing: 0

            Text {
                text: "SESSION LOCKED"
                textFormat: Text.PlainText
                font.family: "JetBrains Mono"
                font.pixelSize: Math.round(12 * editorial.unit)
                font.letterSpacing: Math.round(1.9 * editorial.unit)
                color: editorial.mut
            }

            LockClock {
                topPadding: Math.round(26 * editorial.unit)
                opacity: editorial.ui.showClock ? 1 : 0
                ink: editorial.ink
                dateInk: editorial.dim
                raised: false
                timeSize: Math.round(112 * editorial.unit)
                dateSize: Math.round(25 * editorial.unit)

                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
            }

            // A Column positions its children, so the rule's air above it is
            // the wrapper's height rather than a margin the Column ignores.
            Item {
                width: parent.width
                height: Math.round(46 * editorial.unit) + 1

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Qt.rgba(0.96, 0.94, 0.91, 0.14)
                }
            }

            Row {
                topPadding: Math.round(44 * editorial.unit)
                spacing: Math.round(16 * editorial.unit)

                LockFace {
                    width: Math.round(52 * editorial.unit)
                    height: width
                    image: editorial.ui.userImage
                    userName: editorial.ui.userName
                    ink: editorial.ink
                    fill: Qt.rgba(1, 1, 1, 0.12)
                    ring: Qt.rgba(1, 1, 1, 0.22)
                    ringWidth: 2
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: editorial.ui.userName
                        textFormat: Text.PlainText
                        font.family: "Rubik"
                        font.pixelSize: Math.round(19 * editorial.unit)
                        font.weight: Font.Medium
                        color: editorial.ink
                    }

                    Text {
                        text: "password · PAM"
                        textFormat: Text.PlainText
                        font.family: "JetBrains Mono"
                        font.pixelSize: Math.round(13 * editorial.unit)
                        color: editorial.mut
                    }
                }
            }

            Item {
                width: parent.width
                height: password.height + Math.round(28 * editorial.unit)

                LockPrompt {
                    id: password

                    anchors.bottom: parent.bottom
                    width: parent.width
                    unlock: editorial.ui.unlock
                    unit: editorial.unit
                    chrome: "underline"
                    glyph: ""
                    ink: editorial.ink
                    dim: editorial.mut
                    fieldBorder: editorial.accent
                    showButton: false
                }
            }

            LockMessage {
                topPadding: Math.round(14 * editorial.unit)
                width: parent.width
                unlock: editorial.ui.unlock
                unit: editorial.unit
                align: Text.AlignLeft
                ink: editorial.dim
            }
        }

        // The three the greeter can do, as words, and the status beside them.
        Item {
            x: Math.round(80 * editorial.unit)
            width: parent.width - 2 * x
            height: Math.round(46 * editorial.unit)
            y: parent.height - height - Math.round(64 * editorial.unit)

            LockActions {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: Options.showSessionButtons
                enabled: editorial.ui.unlock.shown
                session: editorial.ui.session
                shape: "text"
                unit: editorial.unit
                spacing: Math.round(26 * editorial.unit)
                ink: editorial.dim
            }

            LockStatus {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                enabled: editorial.ui.unlock.shown
                keyboard: editorial.ui.keyboard
                ink: editorial.dim
                textSize: Math.round(13 * editorial.unit)
                onFocusRequested: editorial.ui.focusPassword()
            }
        }
    }

    // What is playing, low on the wallpaper side, where the design leaves the
    // column free.
    MediaCard {
        id: media

        x: Math.round(64 * editorial.unit)
        y: editorial.height - height - Math.round(150 * editorial.unit)
        width: Math.round(392 * editorial.unit)
        visible: media.hasPlayer && editorial.ui.setting("showMediaControls", true) && editorial.ui.unlock.shown
        textColor: "#ffffff"
    }
}
