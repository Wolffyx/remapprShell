pragma ComponentBehavior: Bound

// The sidebar: what is playing, the machine, the day, and the latest
// notifications, down the right of the screen.
//
// A layer surface that keeps to the usable area, so it sits clear of the
// panel whichever edge that is on. It asks for the keyboard only when clicked,
// and Escape or the close button puts it away; the machine's numbers are read
// only while it is open.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.domain.notifications
import qs.domain.notifications.centre
import qs.domain.session
import qs.domain.status
import qs.domain.status.icons
import qs.domain.surfaces
import qs.domain.system
import qs.domain.system.stats
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    anchors {
        top: true
        bottom: true
        right: true
    }
    margins.top: 16
    margins.bottom: 16
    margins.right: 16
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"
    implicitWidth: 396

    BackgroundEffect.blurRegion: Theme.translucent ? win._card : null
    readonly property Region _card: Region { item: card; radius: card.radius }

    Component.onCompleted: SystemStats.watch(true)
    Component.onDestruction: SystemStats.watch(false)

    readonly property var player: MediaStatus.current
    readonly property SystemClock clock: SystemClock { precision: SystemClock.Minutes }

    property real shown: 0
    NumberAnimation on shown { from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic; running: true }

    component Card: Rectangle {
        default property alias content: inner.data
        width: parent ? parent.width : 0
        height: inner.implicitHeight + 32
        radius: 20
        color: Theme.s2

        Column {
            id: inner
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 12
        }
    }

    component Meter: Column {
        id: meter
        property string label: ""
        property string value: ""
        property real fraction: 0
        width: parent ? parent.width : 0
        spacing: 6

        Item {
            width: parent.width
            height: 16
            PanelText { text: meter.label; font.pixelSize: 12; color: Theme.mut }
            PanelText { anchors.right: parent.right; text: meter.value; font.pixelSize: 12; color: Theme.mut }
        }

        Rectangle {
            width: parent.width
            height: 5
            radius: 2.5
            color: Theme.alpha(Theme.fg, 0.12)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, meter.fraction))
                height: parent.height
                radius: parent.radius
                color: Theme.acc
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: Theme.radius
        color: Theme.glass
        border.width: 1
        border.color: Theme.out
        opacity: win.shown

        transform: Translate { x: (1 - win.shown) * 24 }

        focus: true
        Keys.onEscapePressed: Surfaces.closeAll()

        Flickable {
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width
                spacing: 14

                Item {
                    width: parent.width
                    height: 34

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Sidebar"
                        font.pixelSize: 18
                        font.weight: Font.Medium
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "close"
                        iconName: "window-close"
                        color: Theme.mut
                        onActivated: Surfaces.closeAll()
                    }
                }

                // What is playing.
                Card {
                    Row {
                        width: parent.width
                        spacing: 14

                        Rectangle {
                            width: 86
                            height: 86
                            radius: 16
                            color: Theme.accC
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: win.player?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            Glyph {
                                anchors.centerIn: parent
                                visible: !(win.player?.trackArtUrl)
                                name: "music_note"
                                size: 34
                                color: Theme.accCFg
                            }
                        }

                        Column {
                            width: parent.width - 100
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
                                text: [MediaStatus.artist, win.player?.trackAlbum ?? ""].filter(s => s).join(" · ")
                                font.pixelSize: 13
                                color: Theme.mut
                            }

                            Item {
                                visible: (win.player?.lengthSupported ?? false) && (win.player?.length ?? 0) > 0
                                width: parent.width
                                height: 30

                                Rectangle {
                                    y: 10
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: Theme.alpha(Theme.fg, 0.12)

                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1, (win.player?.position ?? 0) / Math.max(1, win.player?.length ?? 1)))
                                        height: parent.height
                                        radius: parent.radius
                                        color: Theme.acc
                                    }

                                    TapHandler {
                                        onTapped: point => MediaStatus.seek((win.player?.length ?? 0) * point.position.x / parent.width)
                                    }
                                }

                                PanelText {
                                    y: 18
                                    text: StatusIcons.trackTime(win.player?.position ?? 0)
                                    font.family: Theme.monoFamily
                                    font.pixelSize: 11
                                    color: Theme.mut
                                }

                                PanelText {
                                    y: 18
                                    anchors.right: parent.right
                                    text: StatusIcons.trackTime(win.player?.length ?? 0)
                                    font.family: Theme.monoFamily
                                    font.pixelSize: 11
                                    color: Theme.mut
                                }
                            }
                        }
                    }

                    Row {
                        visible: MediaStatus.present
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 14

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: win.player?.shuffleSupported ?? false
                            glyph: "shuffle"
                            color: (win.player?.shuffle ?? false) ? Theme.acc : Theme.fg
                            onActivated: win.player.shuffle = !win.player.shuffle
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
                            visible: win.player?.loopSupported ?? false
                            glyph: (win.player?.loopState ?? MprisLoopState.None) === MprisLoopState.Track ? "repeat_one" : "repeat"
                            color: (win.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None ? Theme.acc : Theme.fg
                            onActivated: {
                                const s = win.player.loopState;
                                win.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
                                                     : s === MprisLoopState.Playlist ? MprisLoopState.Track
                                                     : MprisLoopState.None;
                            }
                        }
                    }
                }

                // The day.
                Card {
                    Row {
                        width: parent.width
                        spacing: 16

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "calendar_month"
                            size: 36
                            color: Theme.acc
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            PanelText {
                                text: win.clock.date.toLocaleDateString(Qt.locale(), "dddd")
                                font.pixelSize: 20
                                font.weight: Font.Medium
                            }

                            PanelText {
                                // The weekday is the line above.
                                text: [win.clock.date.toLocaleDateString(Qt.locale(), "d MMMM yyyy"), Session.uptime].filter(s => s).join(" · ")
                                font.pixelSize: 12
                                color: Theme.mut
                            }
                        }
                    }
                }

                // The machine.
                Card {
                    Meter {
                        label: SystemStats.cpuTemp > 0 ? `CPU · ${SystemStats.cpuTemp} °C` : "CPU"
                        value: `${Math.round(SystemStats.cpu * 100)}%`
                        fraction: SystemStats.cpu
                    }
                    Meter {
                        label: "Memory"
                        value: `${Stats.bytes(SystemStats.memUsed)} / ${Stats.bytes(SystemStats.memTotal)}`
                        fraction: SystemStats.memTotal > 0 ? SystemStats.memUsed / SystemStats.memTotal : 0
                    }
                    Meter {
                        visible: SystemStats.gpu >= 0
                        label: SystemStats.gpuTemp > 0 ? `GPU · ${SystemStats.gpuTemp} °C` : "GPU"
                        value: `${Math.round(Math.max(0, SystemStats.gpu) * 100)}%`
                        fraction: Math.max(0, SystemStats.gpu)
                    }
                    Meter {
                        label: "Network"
                        value: `${Stats.bytes(SystemStats.netRate)}/s`
                        // A gigabit's worth is the whole bar.
                        fraction: SystemStats.netRate / (125 * 1024 * 1024)
                    }
                }

                // The latest notifications, from the history.
                Card {
                    visible: NotificationWatch.enabled && NotificationWatch.entries.length > 0

                    SectionLabel { text: "Latest notifications" }

                    Repeater {
                        model: NotificationWatch.entries.slice(0, 3)

                        Column {
                            id: note
                            required property var modelData
                            width: parent.width

                            Item {
                                width: parent.width
                                height: 18

                                PanelText {
                                    width: parent.width - when.width - 8
                                    elide: Text.ElideRight
                                    text: note.modelData.summary
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                PanelText {
                                    id: when
                                    anchors.right: parent.right
                                    text: Centre.ago(note.modelData.when, win.clock.date.getTime())
                                    font.family: Theme.monoFamily
                                    font.pixelSize: 11
                                    color: Theme.mut
                                }
                            }

                            PanelText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: note.modelData.appName
                                font.pixelSize: 12
                                color: Theme.mut
                            }
                        }
                    }
                }
            }
        }
    }
}
