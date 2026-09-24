/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What is playing, as the day-ahead design's card: art, track, artist and
    album, and the one button. A delegate of LockKeys.players.

    Drawn here rather than by MediaCard because it is another card -- one
    round button rather than three, the album, art that waits on the accent's
    gradient -- and MediaCard taking all of that would be parameters only this
    style sets. The rounded art is LockPicture, as the faces are.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.mpris as Mpris

DayAheadCard {
    id: player

    required property var model

    // The frame, for the accent and for whether the prompt is up.
    required property var ui

    height: player.px(84 + 44)

    Rectangle {
        id: artBack

        x: player.px(22)
        y: player.px(22)
        width: player.px(84)
        height: width
        radius: player.px(16)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#2b2f45" }
            GradientStop { position: 0.55; color: player.ui.accent }
            GradientStop { position: 1; color: "#e0b9a8" }
        }

        Text {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            text: "graphic_eq"
            font.family: "Material Symbols Rounded"
            font.pixelSize: player.px(28)
            color: Qt.rgba(1, 1, 1, 0.8)
        }
    }

    LockPicture {
        id: art

        anchors.fill: artBack
        radius: artBack.radius
        asynchronous: true
        source: player.model.artUrl ?? ""
        sourceSize: Qt.size(artBack.width * 2, artBack.height * 2)
    }

    Column {
        anchors.left: artBack.right
        anchors.leftMargin: player.px(18)
        anchors.right: playButton.left
        anchors.rightMargin: player.px(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: player.px(2)

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: (player.model.track ?? "").length > 0 ? player.model.track : "Nothing playing"
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: player.px(17)
            font.weight: Font.Medium
            color: player.colours.ink
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: [player.model.artist || player.model.identity, player.model.album]
                .filter(p => p).join(" · ")
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: player.px(13)
            color: player.colours.sub
        }
    }

    Text {
        id: playButton

        anchors.right: parent.right
        anchors.rightMargin: player.px(22)
        anchors.verticalCenter: parent.verticalCenter
        text: player.model.playbackStatus === Mpris.PlaybackStatus.Playing ? "pause_circle" : "play_circle"
        font.family: "Material Symbols Rounded"
        font.pixelSize: player.px(40)
        color: player.colours.ink
        opacity: playTap.pressed ? 0.6 : 1

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: playTap
            enabled: player.model.canControl && player.ui.unlock.shown
            onTapped: player.model.container.PlayPause()
        }
        Accessible.role: Accessible.Button
        Accessible.name: "Play or pause"
    }
}
