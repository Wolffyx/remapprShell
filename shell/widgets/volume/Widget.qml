pragma ComponentBehavior: Bound

// The default output's volume.
//
// PipeWire owns the volume and Plasma owns the mixer. This draws the one
// number most people want from a panel and changes it the ways people expect
// -- scroll, middle-click to mute, a slider on click -- and hands everything
// else (a volume per application, profiles, ports) to Plasma's own applet in
// a window of its own, rather than growing a second, lesser mixer.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.platform.kde
import qs.ui.controls
import qs.ui.primitives

BarWidget {
    id: root

    readonly property int step: root.widgetConfig?.step ?? 5
    // The ceiling this widget scrolls and slides to. Zero follows the shell's
    // own -- Settings -> Sound, "Raise maximum volume" -- which is what every
    // other slider reads; a widget that kept a second answer to the same
    // question is how two controls come to stop at different numbers.
    readonly property int ownMax: root.widgetConfig?.maxVolume ?? 0
    readonly property real maxVolume: root.ownMax > 0 ? root.ownMax / 100 : AudioStatus.maxVolume
    readonly property bool showMicrophone: root.widgetConfig?.showMicrophone ?? true

    wantsWheel: true

    tooltip: AudioStatus.sink
        ? `${AudioStatus.nameOf(AudioStatus.sink)}\n${AudioStatus.muted ? "Muted" : StatusIcons.percent(AudioStatus.volume)}`
        : "No sound output"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function handleWheel(delta) {
        AudioStatus.setVolume(StatusIcons.stepVolume(AudioStatus.volume, delta, root.step, root.maxVolume));
    }

    function handleActivate(button) {
        if (button === Qt.MiddleButton) {
            AudioStatus.toggleMute();
            return;
        }
        root.popoutVisible = !root.popoutVisible;
    }

    // A device's level: a mute button that shows it, and a slider that
    // follows the finger. The same for the output and the microphone.
    component Channel: Column {
        id: channel

        required property string title
        required property real level
        required property string iconName
        property real ceiling: 1

        signal setLevel(real value)
        signal toggleMute

        spacing: 2

        PanelText {
            width: parent.width
            text: channel.title
            elide: Text.ElideRight
            color: Theme.foregroundInactive
            font.pixelSize: 11
        }

        Row {
            width: parent.width
            spacing: 6

            IconButton {
                id: mute
                anchors.verticalCenter: parent.verticalCenter
                iconName: channel.iconName
                onActivated: channel.toggleMute()
            }

            NumberSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - mute.width - parent.spacing
                live: true
                from: 0
                // A level already past the cap stays reachable on the slider,
                // rather than the handle pinned at the end of a shorter track.
                to: Math.max(channel.ceiling, channel.level) * 100
                value: channel.level * 100
                onMoved: v => channel.setLevel(v / 100)
            }
        }
    }

    BarButton {
        id: button
        thickness: root.barThickness
        hovered: root.hovered
        active: root.popoutVisible
        size: root.tileSize
        glyph: AudioStatus.glyph
        fallback: AudioStatus.icon
        glyphSize: root.panelIconSize
    }

    popout: Component {
        Item {
            implicitWidth: 320
            implicitHeight: body.implicitHeight

            Column {
                id: body
                width: parent.width
                spacing: 10

                Channel {
                    width: parent.width
                    title: AudioStatus.nameOf(AudioStatus.sink) || "No output"
                    level: AudioStatus.volume
                    iconName: AudioStatus.icon
                    ceiling: root.maxVolume
                    onSetLevel: value => AudioStatus.setVolume(value)
                    onToggleMute: AudioStatus.toggleMute()
                }

                Channel {
                    visible: root.showMicrophone && !!AudioStatus.source
                    width: parent.width
                    title: AudioStatus.nameOf(AudioStatus.source)
                    level: AudioStatus.micVolume
                    ceiling: root.maxVolume
                    iconName: StatusIcons.micIcon(AudioStatus.micVolume, AudioStatus.micMuted)
                    onSetLevel: value => AudioStatus.setMicVolume(value)
                    onToggleMute: AudioStatus.toggleMicMute()
                }

                // Only worth a list when there is a choice to make.
                Column {
                    visible: AudioStatus.sinks.length > 1
                    width: parent.width
                    spacing: 2

                    PanelText {
                        text: "Play through"
                        font.bold: true
                        font.pixelSize: 11
                    }

                    Repeater {
                        model: AudioStatus.sinks

                        Rectangle {
                            id: device

                            required property var modelData
                            readonly property bool current: device.modelData === AudioStatus.sink

                            width: body.width
                            height: 26
                            radius: Theme.radiusOf(5)
                            color: deviceHover.hovered ? Theme.hoverBackground : "transparent"

                            Rectangle {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8
                                height: 8
                                radius: Theme.radiusOf(4)
                                color: device.current ? Theme.accent : "transparent"
                                border.width: 1
                                border.color: device.current ? Theme.accent : Theme.foregroundInactive
                            }

                            PanelText {
                                x: 24
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 30
                                text: AudioStatus.nameOf(device.modelData)
                                elide: Text.ElideRight
                                font.pixelSize: 11
                            }

                            HoverHandler { id: deviceHover }
                            TapHandler { onTapped: AudioStatus.useSink(device.modelData) }
                        }
                    }
                }

                TextButton {
                    text: "Mixer and devices…"
                    iconName: "audio-volume-high"
                    onActivated: {
                        PlasmaApplets.open("org.kde.plasma.volume");
                        root.popoutVisible = false;
                    }
                }
            }
        }
    }
}
