/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Ambient (1c) -- the wallpaper unblurred, ink type instead of white, one
    hairline field. Nothing else until you type.

    Dark text on somebody else's wallpaper is the risk this design takes, so
    the frame's own darkening scrim is replaced by a light one: a veil that
    lifts the picture rather than sinks it, strongest where the clock is. It
    is the smallest thing that makes ink legible over a photograph without
    blurring the photograph, which is the whole point of the style.

    The design's weather line is not drawn. The greeter has no forecast.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

LockStyle {
    id: ambient

    readonly property color ink: "#2a2521"
    readonly property color dim: Qt.rgba(0.16, 0.15, 0.13, 0.8)
    readonly property color hair: Qt.rgba(0.16, 0.15, 0.13, 0.3)

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: password
    promptBlock: promptColumn

    // The veil. Without a wallpaper behind it this is the background.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.82) }
            GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.62) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.74) }
        }
    }

    // --- the corners ------------------------------------------------------

    Row {
        x: Math.round(56 * ambient.unit)
        y: Math.round(52 * ambient.unit)
        spacing: Math.round(10 * ambient.unit)
        visible: media.hasPlayer && ambient.ui.setting("showMediaControls", true)
        opacity: ambient.ui.unlock.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "music_note"
            font.family: "Material Symbols Rounded"
            font.pixelSize: Math.round(19 * ambient.unit)
            color: ambient.dim
        }

        MediaCard {
            id: media

            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(392 * ambient.unit)
            chromeless: true
            textColor: ambient.ink
            unit: ambient.unit
        }
    }

    LockStatus {
        x: ambient.width - width - Math.round(56 * ambient.unit)
        y: Math.round(52 * ambient.unit)
        enabled: ambient.ui.unlock.shown
        ui: ambient.ui
        ink: ambient.dim
        textSize: Math.round(13 * ambient.unit)
    }

    // --- the clock --------------------------------------------------------

    LockClock {
        x: (ambient.width - width) / 2
        y: Math.round(140 * ambient.unit)
        centred: true
        raised: false
        opacity: ambient.ui.showClock ? 1 : 0
        ink: ambient.ink
        dateInk: ambient.dim
        timeSize: Math.round(220 * ambient.unit)
        dateSize: Math.round(22 * ambient.unit)

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
    }

    // --- the prompt -------------------------------------------------------

    Column {
        id: promptColumn

        x: (ambient.width - width) / 2
        y: ambient.height - height - Math.round(150 * ambient.unit)
        width: Math.round(400 * ambient.unit)
        spacing: Math.round(26 * ambient.unit)
        opacity: ambient.ui.unlock.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }

        Row {
            spacing: Math.round(18 * ambient.unit)

            LockFace {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(46 * ambient.unit)
                height: width
                image: ambient.ui.userImage
                userName: ambient.ui.userName
                ink: ambient.ink
                fill: Qt.rgba(0.16, 0.15, 0.13, 0.1)
                ring: ambient.hair
                ringWidth: 1
            }

            LockPrompt {
                id: password

                anchors.verticalCenter: parent.verticalCenter
                width: promptColumn.width - Math.round(64 * ambient.unit)
                unlock: ambient.ui.unlock
                unit: ambient.unit
                chrome: "underline"
                glyph: ""
                showButton: false
                ink: ambient.ink
                dim: ambient.dim
                fieldBorder: ambient.hair
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: ambient.ui.unlock.resting ? "too many attempts · wait a moment"
                                            : "press enter to unlock"
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: Math.round(13.5 * ambient.unit)
            color: ambient.dim
        }

        LockMessage {
            width: parent.width
            unlock: ambient.ui.unlock
            unit: ambient.unit
            ink: ambient.ink
            warn: "#8a5a20"
        }
    }

    LockActions {
        x: (ambient.width - width) / 2
        y: ambient.height - height - Math.round(64 * ambient.unit)
        enabled: ambient.ui.unlock.shown
        opacity: promptColumn.opacity
        session: ambient.ui.session
        unit: ambient.unit
        size: Math.round(44 * ambient.unit)
        ink: ambient.dim
        fill: Qt.rgba(0.16, 0.15, 0.13, 0.07)
        stroke: "transparent"
        hot: Qt.rgba(0.16, 0.15, 0.13, 0.14)
    }
}
