pragma ComponentBehavior: Bound

// The sidebar's card for what is playing. Folded, it is the track; open, the
// controls and how far through it is.

import QtQuick
import Quickshell.Services.Mpris
import qs.domain.status
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

SidebarCard {
    id: mediaCard

    // The player MediaStatus has picked, for what only the player itself can
    // answer: the album and its art, how far through it is, shuffle, repeat.
    readonly property var player: MediaStatus.current

    cardId: "media"
    title: "Playing"
    glyph: "music_note"

    content: [
        Row {
            width: parent.width
            spacing: 14

            AlbumArt {
                width: 56
                height: 56
                radius: 14
                source: mediaCard.player?.trackArtUrl ?? ""
            }

            Column {
                width: parent.width - 70
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                PanelText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: MediaStatus.present ? MediaStatus.title : "Nothing playing"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    color: MediaStatus.present ? Theme.fg : Theme.mut
                }

                PanelText {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: text.length > 0
                    text: [MediaStatus.artist, mediaCard.player?.trackAlbum ?? ""].filter(s => s).join(" · ")
                    font.pixelSize: 13
                    color: Theme.mut
                }
            }
        }
    ]

    extra: Column {
        spacing: 12

        Item {
            visible: (mediaCard.player?.lengthSupported ?? false) && (mediaCard.player?.length ?? 0) > 0
            width: parent.width
            height: 30

            SeekBar {
                y: 6
                width: parent.width
                spacing: 4
                position: mediaCard.player?.position ?? 0
                length: mediaCard.player?.length ?? 0
                canSeek: mediaCard.player?.canSeek ?? false
                trackColor: Theme.alpha(Theme.fg, 0.12)
                trackRadius: 2
                timeFamily: Theme.monoFamily
                timeSize: 11
                onSeek: seconds => MediaStatus.seek(seconds)
            }
        }

        Row {
            visible: MediaStatus.present
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: mediaCard.player?.shuffleSupported ?? false
                glyph: "shuffle"
                color: (mediaCard.player?.shuffle ?? false) ? Theme.acc : Theme.fg
                onActivated: mediaCard.player.shuffle = !mediaCard.player.shuffle
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "skip_previous"
                onActivated: MediaStatus.previous()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 48
                glyph: MediaStatus.playing ? "pause_circle" : "play_circle"
                color: Theme.acc
                onActivated: MediaStatus.toggle()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "skip_next"
                onActivated: MediaStatus.next()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: mediaCard.player?.loopSupported ?? false
                glyph: (mediaCard.player?.loopState ?? MprisLoopState.None) === MprisLoopState.Track ? "repeat_one" : "repeat"
                color: (mediaCard.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None ? Theme.acc : Theme.fg
                onActivated: {
                    const s = mediaCard.player.loopState;
                    mediaCard.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
                                         : s === MprisLoopState.Playlist ? MprisLoopState.Track
                                         : MprisLoopState.None;
                }
            }
        }
    }
}
