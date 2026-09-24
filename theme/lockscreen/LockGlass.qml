/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Glass -- the lock screen this project shipped first, and still the default.

    The wallpaper blurs behind a column of frosted surfaces: a clock that
    rises out of the way when the prompt comes up, the face and the password
    in the middle, what is playing at the bottom left, and the keyboard,
    layout and battery in a pill at the bottom right.

    The one style whose clock can be moved (`lockscreen set clock left|center`),
    because it is the one with room on both sides for it.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

LockStyle {
    id: glass

    readonly property bool clockLeft: Options.clockPosition !== "center"

    promptField: password
    promptBlock: promptColumn

    LockClock {
        id: clock

        x: glass.clockLeft ? glass.ui.edge : (glass.width - width) / 2
        y: glass.ui.unlock.shown ? Math.round(glass.height * 0.1) : Math.round(glass.height * 0.3)
        centred: !glass.clockLeft
        opacity: glass.ui.showClock ? 1 : 0
        ink: glass.ui.fg
        timeSize: Math.round(132 * glass.unit)
        dateSize: Math.round(22 * glass.unit)

        Behavior on y { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
    }

    // "Locked", under the clock, in the design's pill.
    Rectangle {
        x: glass.clockLeft ? glass.ui.edge : (glass.width - width) / 2
        y: clock.y + clock.height + Math.round(20 * glass.unit)
        width: pillRow.width + 26
        height: 34
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)
        opacity: clock.opacity

        Row {
            id: pillRow

            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "lock"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 17
                color: glass.ui.fg
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: glass.ui.unlock.resting ? "Locked · wait a moment" : "Locked"
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: 13
                color: glass.ui.fg
            }
        }
    }

    // --- the prompt ------------------------------------------------------

    Item {
        anchors.fill: parent
        opacity: glass.ui.unlock.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }

        MediaCard {
            id: media

            x: glass.ui.edge
            y: glass.height - height - Math.round(64 * glass.unit)
            width: Math.round(392 * glass.unit)
            visible: media.hasPlayer && glass.ui.setting("showMediaControls", true) && glass.ui.unlock.shown
            textColor: glass.ui.fg
            unit: glass.unit
        }

        Column {
            id: promptColumn

            x: (glass.width - width) / 2
            y: glass.height - height - Math.round(110 * glass.unit)
            width: Math.round(392 * glass.unit)
            spacing: Math.round(18 * glass.unit)

            LockFace {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(96 * glass.unit)
                height: width
                image: glass.ui.userImage
                userName: glass.ui.userName
                ink: glass.ui.fg
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: glass.ui.userName
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: glass.ui.fg
                font.family: "Rubik"
                font.pixelSize: Math.round(20 * glass.unit)
                font.weight: Font.Medium
            }

            LockPrompt {
                id: password

                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                unlock: glass.ui.unlock
                unit: glass.unit
                ink: glass.ui.fg
            }

            LockMessage {
                width: parent.width
                unlock: glass.ui.unlock
                unit: glass.unit
                ink: glass.ui.fg
            }

            LockActions {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Options.showSessionButtons
                enabled: glass.ui.unlock.shown
                session: glass.ui.session
                unit: glass.unit
                ink: glass.ui.fg
            }
        }

        // The keyboard, the layout and the battery, in the design's pill.
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: Math.round(44 * glass.unit)
            anchors.bottomMargin: Math.round(38 * glass.unit)
            width: statusRow.width + 32
            height: 44
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.14)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.2)
            enabled: glass.ui.unlock.shown

            LockStatus {
                id: statusRow

                anchors.centerIn: parent
                keyboard: glass.ui.keyboard
                ink: glass.ui.fg
                onFocusRequested: glass.ui.focusPassword()
            }
        }
    }
}
