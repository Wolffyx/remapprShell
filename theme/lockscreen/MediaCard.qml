/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What is playing, as the design draws it: the art, the track, a line of
    progress and three buttons.

    The players come from `org.kde.plasma.private.mpris`, which is the module
    Plasma's own lock screen uses -- the greeter has no session of ours to ask,
    and this way a player that Plasma's lock screen can control is one this one
    can control too. Shown only when Plasma's own "show media controls" setting
    is on, which is the setting System Settings already offers.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.mpris as Mpris

Item {
    id: card

    property color textColor: "#ffffff"

    // The styles that put this on a bar or beside a line of type want the
    // track and the buttons without the frosted box around them.
    property bool chromeless: false

    property color cardColor: Qt.rgba(1, 1, 1, 0.15)
    property color cardBorder: Qt.rgba(1, 1, 1, 0.22)

    // Whether there is anything to draw. Read from outside as well: the lock
    // screen composes it with its own reasons for hiding the card, and a
    // `visible` set there would otherwise override this one and leave an
    // empty box where no player is.
    readonly property bool hasPlayer: players.count > 0

    implicitHeight: 104
    visible: card.hasPlayer

    Rectangle {
        anchors.fill: parent
        visible: !card.chromeless
        radius: 22
        color: card.cardColor
        border.width: 1
        border.color: card.cardBorder
    }

    Repeater {
        id: players
        model: Mpris.MultiplexerModel {}

        Item {
            id: row

            required property var model

            anchors.fill: parent

            Image {
                id: art
                x: 16
                y: 16
                width: 72
                height: 72
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: row.model.artUrl
                sourceSize: Qt.size(144, 144)
                visible: status === Image.Ready
            }

            Rectangle {
                x: 16
                y: 16
                width: 72
                height: 72
                radius: 14
                visible: art.status !== Image.Ready
                color: Qt.rgba(1, 1, 1, 0.18)

                Text {
                    anchors.centerIn: parent
                    text: "music_note"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 30
                    color: card.textColor
                }
            }

            Column {
                x: 102
                width: parent.width - 102 - 48
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.model.track.length > 0 ? row.model.track : "Nothing playing"
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    color: card.textColor
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.model.artist || row.model.identity
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.82)
                }
            }

            Column {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: [
                        { glyph: "skip_previous", act: () => row.model.container.Previous() },
                        { glyph: row.model.playbackStatus === Mpris.PlaybackStatus.Playing ? "pause" : "play_arrow",
                          act: () => row.model.container.PlayPause() },
                        { glyph: "skip_next", act: () => row.model.container.Next() }
                    ]

                    Item {
                        id: button

                        required property var modelData

                        width: 26
                        height: 26

                        Text {
                            anchors.centerIn: parent
                            text: button.modelData.glyph
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 22
                            color: card.textColor
                            opacity: press.pressed ? 0.6 : 1
                        }

                        TapHandler {
                            id: press
                            enabled: row.model.canControl
                            onTapped: button.modelData.act()
                        }
                    }
                }
            }
        }
    }
}
