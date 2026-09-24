pragma ComponentBehavior: Bound

// What is playing, on the two-pane start menu's side: the cover, the title and
// the artist, and the three buttons.
//
// No card of its own: inside a popout that is already a card, a second one is
// just another background.

import QtQuick
import qs.domain.status
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Item {
    height: player.implicitHeight + 28

    Column {
        id: player
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 10

        Row {
            width: parent.width
            spacing: 12

            AlbumArt {
                width: 56
                height: 56
                source: MediaStatus.current?.trackArtUrl ?? ""
            }

            Column {
                width: parent.width - 68
                anchors.verticalCenter: parent.verticalCenter

                PanelText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: MediaStatus.present ? MediaStatus.title : "Nothing playing"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: MediaStatus.present ? Theme.fg : Theme.mut
                }

                PanelText {
                    visible: text.length > 0
                    width: parent.width
                    elide: Text.ElideRight
                    text: MediaStatus.artist
                    font.pixelSize: 12
                    color: Theme.mut
                }
            }
        }

        Row {
            visible: MediaStatus.present
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            IconButton { glyph: "skip_previous"; onActivated: MediaStatus.previous() }
            IconButton {
                size: 40
                glyph: MediaStatus.playing ? "pause_circle" : "play_circle"
                color: Theme.acc
                onActivated: MediaStatus.toggle()
            }
            IconButton { glyph: "skip_next"; onActivated: MediaStatus.next() }
        }
    }
}
