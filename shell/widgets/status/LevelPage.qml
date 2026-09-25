pragma ComponentBehavior: Bound

// Quick settings' page for sound, and for the microphone: the level, the
// devices to use, and the one setting that belongs beside them.
//
// One component for both: an output and an input differ in which node they
// write to and in nothing else anybody looking at the page would name. Two
// copies of this drifted apart in every shell that has written them.

import QtQuick
import qs.domain.config
import qs.domain.status
import qs.domain.theme
import qs.platform.kde
import qs.ui.primitives
import qs.ui.controls

Column {
    id: level

    // The status widget: its `page` is where the header goes back to.
    required property var widget

    property string title: ""
    property string glyph: ""
    property var devices: []
    property var current: null
    property real volume: 0
    property bool muted: false
    property string emptyText: ""

    signal setLevel(real value)
    signal setMuted(bool value)
    signal use(var node)

    spacing: 12

    PageHeader {
        widget: level.widget
        title: level.title
        switchedOn: !level.muted
        onSwitched: on => level.setMuted(!on)
    }

    // The level itself, so the page it was reached from is not the only place
    // to set it.
    LevelSlider {
        width: parent.width
        glyph: level.glyph
        sliderEnabled: !level.muted
        to: Math.round(AudioStatus.ceilingFor(level.volume) * 100)
        value: level.volume * 100
        onMoved: v => level.setLevel(v / 100)
        onIconActivated: level.setMuted(!level.muted)
    }

    PanelText {
        visible: level.devices.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.mut
        font.pixelSize: 12
        leftPadding: 4
        text: level.emptyText
    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: level.devices

            ItemRow {
                required property var modelData
                glyph: level.glyph
                title: AudioStatus.nameOf(modelData)
                current: modelData === level.current
                mark: modelData === level.current ? "check" : ""
                onActivated: level.use(modelData)
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.out
    }

    // The one thing on these pages that is a setting rather than a state: it
    // is written to the configuration and every slider in the shell reads it,
    // which is why it is here rather than being a mode this popout remembers
    // by itself.
    ToggleRow {
        width: parent.width
        label: "Raise maximum volume"
        description: "Up to 150%, amplified in software. It distorts on most hardware."
        checked: AudioStatus.raiseMax
        onToggled: value => ConfigStore.set("audio.raiseMaxVolume", value)
    }

    TextButton {
        glyph: "tune"
        iconName: "preferences-desktop-sound"
        text: "Sound settings…"
        onActivated: {
            PlasmaApplets.openSettings("kcm_pulseaudio");
            level.widget.closePopout();
        }
    }
}
