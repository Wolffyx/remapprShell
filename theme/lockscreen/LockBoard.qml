/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Widget board (2a) -- the lock as a dashboard: a grid of cards you can read
    in one glance, with the password as the bar along the foot.

    The design's grid has six cards. Three of them -- weather, the next
    calendar entry, and the notification list -- are things the greeter cannot
    know: it is a separate process with no session, no calendar and no
    notification history, and the Lock page says as much about the last of
    them. They are not drawn, and the grid closes up rather than leaving
    placeholders where an answer would go.

    What is left is real: the time and the greeting, what is playing, and the
    machine's own state. The cards keep the design's proportions, so the board
    still reads as a board.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

LockStyle {
    id: board

    readonly property color ink: "#ffffff"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.8)
    readonly property int cardRadius: Math.round(26 * board.unit)

    promptField: password
    promptBlock: authBar

    readonly property string greeting: {
        const h = clock.now.getHours();
        if (h < 5) return "Good night";
        if (h < 12) return "Good morning";
        if (h < 18) return "Good afternoon";
        return "Good evening";
    }

    component Card: Rectangle {
        radius: board.cardRadius
        color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
    }

    // --- the head ---------------------------------------------------------

    Item {
        id: head

        x: board.ui.edge
        width: board.width - 2 * x
        y: Math.round(80 * board.unit)
        height: Math.round(28 * board.unit)
        opacity: board.ui.unlock.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(12 * board.unit)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "lock"
                font.family: "Material Symbols Rounded"
                font.pixelSize: Math.round(20 * board.unit)
                color: board.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: board.ui.unlock.resting ? "Locked · wait a moment" : "Locked"
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: Math.round(16 * board.unit)
                font.weight: Font.Medium
                color: board.ink
            }
        }

        LockStatus {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            enabled: board.ui.unlock.shown
            keyboard: board.ui.keyboard
            ink: board.ink
            textSize: Math.round(13 * board.unit)
            onFocusRequested: board.ui.focusPassword()
        }
    }

    // --- the grid ---------------------------------------------------------

    // Two columns rather than a four-column grid with spans. The design's
    // grid assumes six cards; three of them are things the greeter cannot
    // know, and a GridLayout with the rest in it left a hole where the
    // missing row would have been. Sized by hand, the right column simply
    // closes up when there is no player.
    Item {
        id: grid

        x: board.ui.edge
        width: board.width - 2 * x
        y: head.y + head.height + Math.round(48 * board.unit)
        height: authBar.y - y - Math.round(28 * board.unit)

        readonly property int gap: Math.round(20 * board.unit)
        readonly property int colW: Math.round((width - gap) / 2)

        // The clock card, which is the one every other card is sized against.
        Card {
            width: grid.colW
            height: grid.height
            color: Qt.rgba(1, 1, 1, 0.14)
            border.color: Qt.rgba(1, 1, 1, 0.2)

            Item {
                anchors.fill: parent
                anchors.margins: Math.round(32 * board.unit)

                Text {
                    anchors.top: parent.top
                    text: clock.now.toLocaleDateString(Qt.locale(), "dddd d MMMM").toUpperCase()
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.round(12 * board.unit)
                    font.letterSpacing: Math.round(1.7 * board.unit)
                    color: Qt.rgba(1, 1, 1, 0.72)
                }

                Column {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    spacing: Math.round(16 * board.unit)

                    LockClock {
                        id: clock

                        showDate: false
                        raised: false
                        opacity: board.ui.showClock ? 1 : 0
                        ink: board.ink
                        timeSize: Math.round(126 * board.unit)

                        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                    }

                    Text {
                        width: parent.width
                        text: `${board.greeting}, ${board.ui.userName}`
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: "Rubik"
                        font.pixelSize: Math.round(24 * board.unit)
                        font.weight: Font.Light
                        color: board.dim
                    }
                }
            }
        }

        Column {
            x: grid.colW + grid.gap
            width: grid.colW
            height: grid.height
            spacing: grid.gap

            // What is playing, when something is. The card goes with the
            // player: an empty box labelled "nothing" is worse than one card
            // fewer, and the card below it takes the space back.
            Card {
                id: mediaCard

                width: parent.width
                height: Math.round((grid.height - grid.gap) / 2)
                visible: media.hasPlayer && board.ui.setting("showMediaControls", true)

                MediaCard {
                    id: media

                    anchors.fill: parent
                    anchors.margins: Math.round(14 * board.unit)
                    chromeless: true
                    textColor: board.ink
                    unit: board.unit
                }
            }

            // The machine's own state, which is what the weather card's
            // corner of the grid is given to instead.
            Card {
                width: parent.width
                height: mediaCard.visible ? Math.round((grid.height - grid.gap) / 2) : grid.height

                Item {
                    anchors.fill: parent
                    anchors.margins: Math.round(26 * board.unit)

                    Text {
                        anchors.top: parent.top
                        text: "THIS SCREEN"
                        textFormat: Text.PlainText
                        font.family: "JetBrains Mono"
                        font.pixelSize: Math.round(12 * board.unit)
                        font.letterSpacing: Math.round(1.5 * board.unit)
                        color: Qt.rgba(1, 1, 1, 0.72)
                    }

                    Column {
                        anchors.bottom: parent.bottom
                        spacing: Math.round(8 * board.unit)

                        Text {
                            text: Screen.name
                            textFormat: Text.PlainText
                            font.family: "Rubik"
                            font.pixelSize: Math.round(30 * board.unit)
                            font.weight: Font.Light
                            color: board.ink
                        }

                        Text {
                            text: `${Screen.width}×${Screen.height}`
                            textFormat: Text.PlainText
                            font.family: "Rubik"
                            font.pixelSize: Math.round(14 * board.unit)
                            color: board.dim
                        }
                    }
                }
            }
        }
    }

    // --- the foot ---------------------------------------------------------

    Item {
        id: authBar

        x: board.ui.edge
        width: board.width - 2 * x
        height: Math.round(76 * board.unit)
        y: board.height - height - Math.round(64 * board.unit)
        opacity: board.ui.unlock.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }

        Card {
            id: authCard

            anchors.left: parent.left
            anchors.right: actions.visible ? actions.left : parent.right
            anchors.rightMargin: actions.visible ? Math.round(12 * board.unit) : 0
            height: parent.height
            color: Qt.rgba(1, 1, 1, 0.16)
            border.color: Qt.rgba(1, 1, 1, 0.26)

            Row {
                id: who

                anchors.left: parent.left
                anchors.leftMargin: Math.round(22 * board.unit)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(16 * board.unit)

                LockFace {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(48 * board.unit)
                    height: width
                    image: board.ui.userImage
                    userName: board.ui.userName
                    ink: board.ink
                    ringWidth: 2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: board.ui.userName
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: "Rubik"
                    font.pixelSize: Math.round(16 * board.unit)
                    font.weight: Font.Medium
                    color: board.ink
                }
            }

            LockPrompt {
                id: password

                anchors.left: who.right
                anchors.leftMargin: Math.round(18 * board.unit)
                anchors.right: parent.right
                anchors.rightMargin: Math.round(12 * board.unit)
                anchors.verticalCenter: parent.verticalCenter
                unlock: board.ui.unlock
                unit: board.unit
                chrome: "none"
                glyph: ""
                ink: board.ink
                dim: Qt.rgba(1, 1, 1, 0.66)
            }
        }

        LockActions {
            id: actions

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Options.showSessionButtons
            enabled: board.ui.unlock.shown
            session: board.ui.session
            shape: "square"
            unit: board.unit
            size: parent.height
            spacing: Math.round(12 * board.unit)
            ink: board.ink
        }
    }

    LockMessage {
        x: board.ui.edge
        y: authBar.y - height - Math.round(12 * board.unit)
        width: authBar.width
        opacity: authBar.opacity
        unlock: board.ui.unlock
        unit: board.unit
        align: Text.AlignLeft
        ink: board.ink
    }
}
