// The cover of what is playing, or something standing in for it.
//
// The picture is cropped to fill the tile. Until it has loaded -- and where
// there is none, or it will not load -- a stand-in is drawn in the middle
// instead: a Material Symbols glyph, or with `glyph` cleared a theme icon, as
// IconButton chooses between them. The player's own icon makes a good one.
//
//   AlbumArt {
//       width: 56
//       height: 56
//       source: MediaStatus.current?.trackArtUrl ?? ""
//   }

import QtQuick
import qs.domain.theme

Rectangle {
    id: root

    // The picture: MPRIS's `trackArtUrl`, a file or a web address.
    property string source: ""

    // The stand-in, as a glyph...
    property string glyph: "music_note"
    property real glyphSize: 26
    property color glyphColor: Theme.accCFg

    // ...or, with `glyph` empty, as a theme icon.
    property string iconName: ""
    property string fallbackIcon: "media-album-cover"
    property real iconSize: 32

    readonly property bool loaded: art.status === Image.Ready

    implicitWidth: 56
    implicitHeight: 56
    radius: Theme.radiusOf(12)
    color: Theme.accC
    clip: true

    Image {
        id: art
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: root.loaded
    }

    Glyph {
        anchors.centerIn: parent
        visible: !root.loaded && root.glyph.length > 0
        name: root.glyph
        size: root.glyphSize
        color: root.glyphColor
    }

    PanelIcon {
        anchors.centerIn: parent
        visible: !root.loaded && root.glyph.length === 0
        implicitSize: root.iconSize
        iconName: root.iconName
        fallbackName: root.fallbackIcon
    }
}
