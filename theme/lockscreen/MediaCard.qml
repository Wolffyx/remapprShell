/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What is playing, as the design draws it: the art, the track and who it is
    by, and three buttons.

    The players come from LockKeys, out of `org.kde.plasma.private.mpris`,
    which is the module Plasma's own lock screen uses -- the greeter has no
    session of ours to ask, and this way a player that Plasma's lock screen can
    control is one this one can control too. Shown only when Plasma's own
    "show media controls" setting is on, which is the setting System Settings
    already offers.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.mpris as Mpris

Item {
    id: card

    property color textColor: "#ffffff"
    // The artist's line, and the box that stands in for missing art: the
    // text's own colour, fainter. Not white whatever the text is, which was
    // white on white over the ambient style's pale veil.
    property color subColor: Qt.alpha(card.textColor, 0.82)
    property color placeholderColor: Qt.alpha(card.textColor, 0.18)

    // The frame's scale, as every other part takes it.
    property real unit: 1

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

    implicitHeight: Math.round(104 * card.unit)
    visible: card.hasPlayer

    Rectangle {
        anchors.fill: parent
        visible: !card.chromeless
        radius: Math.round(22 * card.unit)
        color: card.cardColor
        border.width: 1
        border.color: card.cardBorder
    }

    Repeater {
        id: players
        model: LockKeys.players

        Item {
            id: row

            required property var model

            anchors.fill: parent

            Image {
                id: art
                x: Math.round(16 * card.unit)
                y: Math.round(16 * card.unit)
                width: Math.round(72 * card.unit)
                height: Math.round(72 * card.unit)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: row.model.artUrl
                sourceSize: Qt.size(Math.round(144 * card.unit), Math.round(144 * card.unit))
                visible: status === Image.Ready
            }

            Rectangle {
                x: Math.round(16 * card.unit)
                y: Math.round(16 * card.unit)
                width: Math.round(72 * card.unit)
                height: Math.round(72 * card.unit)
                radius: Math.round(14 * card.unit)
                visible: art.status !== Image.Ready
                color: card.placeholderColor

                SymbolText {
                    anchors.centerIn: parent
                    symbol: "music_note"
                    font.pixelSize: Math.round(30 * card.unit)
                    color: card.textColor
                }
            }

            Column {
                x: Math.round(102 * card.unit)
                width: parent.width - Math.round(102 * card.unit) - Math.round(48 * card.unit)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(2 * card.unit)

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.model.track.length > 0 ? row.model.track : "Nothing playing"
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(15 * card.unit)
                    font.weight: Font.Medium
                    color: card.textColor
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.model.artist || row.model.identity
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(12 * card.unit)
                    color: card.subColor
                }
            }

            Column {
                anchors.right: parent.right
                anchors.rightMargin: Math.round(14 * card.unit)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(4 * card.unit)

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

                        width: Math.round(26 * card.unit)
                        height: Math.round(26 * card.unit)

                        SymbolText {
                            anchors.centerIn: parent
                            symbol: button.modelData.glyph
                            font.pixelSize: Math.round(22 * card.unit)
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
