/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Poster (2b) -- the image is the design. One strip along the foot carries
    the time, the password and the status; everything else gets out of the way.

    The wallpaper is not blurred: blurring it would be blurring the design.
    The frame's even scrim is replaced by one that is heavy at the foot and
    gone by the middle, so the strip has something to sit on and the top two
    thirds of the picture are untouched.

    The design's "2 notifications hidden · press n" is not drawn. There is
    nothing behind it: the greeter has no notification history to reveal, so
    the key would do nothing and the line would be a promise.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

LockStyle {
    id: poster

    readonly property color ink: "#ffffff"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.78)

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: password
    promptBlock: strip

    // Heavy at the foot, gone by the middle.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.03, 0.03, 0.02, 0.18) }
            GradientStop { position: 0.38; color: Qt.rgba(0.03, 0.03, 0.02, 0.0) }
            GradientStop { position: 0.66; color: Qt.rgba(0.03, 0.03, 0.02, 0.5) }
            GradientStop { position: 1.0; color: Qt.rgba(0.03, 0.03, 0.02, 0.92) }
        }
    }

    // --- the time ---------------------------------------------------------

    LockClock {
        x: poster.ui.edge
        y: strip.y - height - Math.round(80 * poster.unit)
        opacity: poster.ui.showClock ? 1 : 0
        ink: poster.ink
        dateInk: Qt.rgba(1, 1, 1, 0.88)
        timeSize: Math.round(190 * poster.unit)
        dateSize: Math.round(27 * poster.unit)

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
    }

    // --- the strip --------------------------------------------------------

    Item {
        id: strip

        x: poster.ui.edge
        width: poster.width - 2 * x
        height: Math.round(84 * poster.unit)
        y: poster.height - height - Math.round(84 * poster.unit)
        opacity: poster.ui.unlock.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.22)
        }

        Row {
            id: who

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Math.round(14 * poster.unit)
            spacing: Math.round(14 * poster.unit)

            LockFace {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(44 * poster.unit)
                height: width
                image: poster.ui.userImage
                userName: poster.ui.userName
                ink: poster.ink
                ringWidth: 2
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: poster.ui.userName
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(16 * poster.unit)
                    font.weight: Font.Medium
                    color: poster.ink
                }

                Text {
                    text: Screen.name
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.round(12 * poster.unit)
                    color: poster.dim
                }
            }
        }

        LockPrompt {
            id: password

            anchors.left: who.right
            anchors.leftMargin: Math.round(28 * poster.unit)
            anchors.right: tail.left
            anchors.rightMargin: Math.round(28 * poster.unit)
            anchors.verticalCenter: who.verticalCenter
            height: Math.round(54 * poster.unit)
            unlock: poster.ui.unlock
            unit: poster.unit
            glyph: "password"
            radius: Math.round(14 * poster.unit)
            ink: poster.ink
            dim: poster.dim
            fieldColor: Qt.rgba(1, 1, 1, 0.12)
            fieldBorder: Qt.rgba(1, 1, 1, 0.26)
        }

        Row {
            id: tail

            anchors.right: parent.right
            anchors.verticalCenter: who.verticalCenter
            spacing: Math.round(20 * poster.unit)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: media.hasPlayer && poster.ui.setting("showMediaControls", true)
                spacing: Math.round(8 * poster.unit)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "music_note"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Math.round(19 * poster.unit)
                    color: poster.ink
                }

                MediaCard {
                    id: media

                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(300 * poster.unit)
                    chromeless: true
                    textColor: poster.ink
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Math.round(18 * poster.unit)
                color: Qt.rgba(1, 1, 1, 0.3)
            }

            LockStatus {
                anchors.verticalCenter: parent.verticalCenter
                enabled: poster.ui.unlock.shown
                keyboard: poster.ui.keyboard
                ink: poster.ink
                textSize: Math.round(12.5 * poster.unit)
                onFocusRequested: poster.ui.focusPassword()
            }

            LockActions {
                anchors.verticalCenter: parent.verticalCenter
                visible: Options.showSessionButtons
                enabled: poster.ui.unlock.shown
                session: poster.ui.session
                unit: poster.unit
                size: Math.round(40 * poster.unit)
                spacing: Math.round(8 * poster.unit)
                ink: poster.ink
                fill: Qt.rgba(1, 1, 1, 0.1)
                stroke: Qt.rgba(1, 1, 1, 0.18)
            }
        }
    }

    LockMessage {
        x: poster.ui.edge
        y: strip.y - height - Math.round(10 * poster.unit)
        width: Math.round(520 * poster.unit)
        opacity: strip.opacity
        unlock: poster.ui.unlock
        unit: poster.unit
        align: Text.AlignLeft
        ink: poster.ink
    }
}
