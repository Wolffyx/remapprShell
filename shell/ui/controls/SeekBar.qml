// Where in the track, and a click on the bar to go elsewhere in it when the
// player allows that: a thin bar filled up to the position, and the position
// and the length under its two ends.
//
// `position` and `length` are in seconds, as MPRIS gives them; `seek` asks
// for a position in the same. A click lands only where `canSeek` says the
// player will take one -- a bar that looks clickable and does nothing is
// worse than a bar that does not look it.
//
//   SeekBar {
//       width: parent.width
//       position: player?.position ?? 0
//       length: player?.length ?? 0
//       canSeek: player?.canSeek ?? false
//       onSeek: seconds => MediaStatus.seek(seconds)
//   }

import QtQuick
import qs.domain.status.icons
import qs.domain.theme
import qs.ui.primitives

Column {
    id: root

    property real position: 0
    property real length: 0
    property bool canSeek: false

    // How it looks. The defaults are the media widget's.
    property color trackColor: Theme.alpha(Theme.fg, 0.2)
    property color fillColor: Theme.acc
    property real trackRadius: Theme.radiusOf(2)
    property color timeColor: Theme.mut
    property string timeFamily: Theme.fontFamily
    property int timeSize: 10

    signal seek(real position)

    spacing: 3

    Rectangle {
        id: track
        width: parent.width
        height: 4
        radius: root.trackRadius
        color: root.trackColor

        Rectangle {
            width: parent.width * Math.min(1, root.position / Math.max(1, root.length))
            height: parent.height
            radius: parent.radius
            color: root.fillColor
        }

        TapHandler {
            enabled: root.canSeek
            // A 4px bar is a small target; the handler's margin makes the
            // band around it count too.
            margin: 6
            onTapped: point => root.seek(point.position.x / track.width * root.length)
        }
    }

    Item {
        width: parent.width
        height: elapsed.implicitHeight

        PanelText {
            id: elapsed
            text: StatusIcons.trackTime(root.position)
            color: root.timeColor
            font.family: root.timeFamily
            font.pixelSize: root.timeSize
        }

        PanelText {
            anchors.right: parent.right
            text: StatusIcons.trackTime(root.length)
            color: root.timeColor
            font.family: root.timeFamily
            font.pixelSize: root.timeSize
        }
    }
}
