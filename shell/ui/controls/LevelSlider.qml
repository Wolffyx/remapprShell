// A level and the button beside it: an icon to press -- to mute, as a rule --
// and a slider that follows the finger, with room at the end of the line for
// whatever else the line needs, such as the way to a page behind it.
//
// `value`, `from` and `to` are in percent, as NumberSlider's are. The end of
// the track is the caller's to say because callers say it differently: the
// volume widget keeps a level already past its cap reachable, quick settings
// rounds the ceiling to a whole percent.
//
// Anything written inside goes at the end of the line, after the slider,
// which gives up the room it takes -- only while it is showing. Centre it
// with `anchors.verticalCenter: parent.verticalCenter`.
//
//   LevelSlider {
//       value: AudioStatus.volume * 100
//       to: Math.round(AudioStatus.ceilingFor(AudioStatus.volume) * 100)
//       glyph: AudioStatus.glyph
//       onMoved: v => AudioStatus.setVolume(v / 100)
//       onIconActivated: AudioStatus.toggleMute()
//   }

import QtQuick

Row {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100

    // The slider alone: a muted channel's level cannot be dragged, but its
    // button still unmutes it.
    property bool sliderEnabled: true

    // The button's icon: a Material Symbols glyph, a theme icon, or both --
    // as IconButton draws them.
    property string glyph: ""
    property string iconName: ""

    // Every step of a drag, not only its end: a level should follow the
    // finger, and costs nothing to write.
    signal moved(real value)
    signal iconActivated

    // The room the things at the end of the line take, the spacing before
    // each included.
    readonly property real trailingWidth: {
        let taken = 0;
        for (const child of root.children) {
            if (child !== icon && child !== slider && child.visible)
                taken += child.width + root.spacing;
        }
        return taken;
    }

    spacing: 10

    IconButton {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        glyph: root.glyph
        iconName: root.iconName
        onActivated: root.iconActivated()
    }

    NumberSlider {
        id: slider
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - icon.width - root.spacing - root.trailingWidth
        live: true
        enabled: root.sliderEnabled
        from: root.from
        to: root.to
        value: root.value
        onMoved: v => root.moved(v)
    }
}
