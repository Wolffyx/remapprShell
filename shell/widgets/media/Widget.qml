pragma ComponentBehavior: Bound

// What is playing, and the buttons for it.
//
// Plasma shows this from inside its system tray, so under our renderer there
// was nothing: the tray we draw is only StatusNotifierItems. This reads MPRIS
// directly, draws the title and three buttons, and hands everything else to
// Plasma's own applet or to the player itself. Absent while nothing is open.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.platform.kde
import qs.ui.controls
import qs.ui.primitives

BarWidget {
    id: root

    readonly property int size: Math.max(22, Math.round(40 * root.unit))

    readonly property bool showTitle: root.widgetConfig?.showTitle ?? true
    readonly property int maxWidth: root.widgetConfig?.maxWidth ?? 180
    readonly property bool horizontal: root.bar?.horizontal ?? true
    readonly property var player: MediaStatus.current

    present: MediaStatus.present

    tooltip: [MediaStatus.title, MediaStatus.artist, MediaStatus.playing ? "" : "Paused"]
        .filter(s => s).join("\n")

    implicitWidth: Math.max(root.size, row.implicitWidth + 2 * Math.round(12 * Math.max(0.7, root.unit)))
    implicitHeight: root.size

    function handleActivate(button) {
        if (button === Qt.MiddleButton) {
            MediaStatus.toggle();
            return;
        }
        root.popoutVisible = !root.popoutVisible;
    }

    BarButton {
        anchors.fill: parent
        thickness: root.bar?.thickness ?? 40
        hovered: root.hovered
        active: root.popoutVisible
        size: root.size
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            name: MediaStatus.playing ? "graphic_eq" : "pause"
            fallback: MediaStatus.playing ? "media-playback-playing" : "media-playback-paused"
            size: root.panelIconSize
            color: MediaStatus.playing ? Theme.acc : Theme.mut
        }

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showTitle && root.horizontal && text.length > 0
            width: Math.min(implicitWidth, root.maxWidth)
            elide: Text.ElideRight
            text: MediaStatus.title
        }
    }

    popout: Component {
        Item {
            implicitWidth: 320
            implicitHeight: body.implicitHeight

            Column {
                id: body
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        width: 64
                        height: 64
                        radius: 6
                        color: Theme.alpha(Theme.foreground, 0.08)
                        clip: true

                        Image {
                            id: art
                            anchors.fill: parent
                            source: root.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: art.status === Image.Ready
                        }

                        PanelIcon {
                            anchors.centerIn: parent
                            visible: !art.visible
                            implicitSize: 32
                            iconName: root.player?.desktopEntry ?? ""
                            fallbackName: "media-album-cover"
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 74
                        spacing: 2

                        PanelText {
                            width: parent.width
                            text: MediaStatus.title
                            elide: Text.ElideRight
                            font.bold: true
                        }

                        PanelText {
                            width: parent.width
                            visible: text.length > 0
                            text: MediaStatus.artist
                            elide: Text.ElideRight
                            font.pixelSize: 11
                        }

                        PanelText {
                            width: parent.width
                            visible: text.length > 0
                            text: root.player?.trackAlbum ?? ""
                            elide: Text.ElideRight
                            color: Theme.foregroundInactive
                            font.pixelSize: 10
                        }
                    }
                }

                // Where in the track, and a click on the bar to go elsewhere
                // in it, when the player allows that.
                Column {
                    visible: (root.player?.lengthSupported ?? false) && (root.player?.length ?? 0) > 0
                    width: parent.width
                    spacing: 3

                    Rectangle {
                        id: track
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Theme.alpha(Theme.foreground, 0.2)

                        Rectangle {
                            width: parent.width * Math.min(1, (root.player?.position ?? 0) / Math.max(1, root.player?.length ?? 1))
                            height: parent.height
                            radius: parent.radius
                            color: Theme.accent
                        }

                        TapHandler {
                            enabled: root.player?.canSeek ?? false
                            // A 4px bar is a small target; the handler's
                            // margin makes the band around it count too.
                            margin: 6
                            onTapped: point => MediaStatus.seek(point.position.x / track.width * (root.player?.length ?? 0))
                        }
                    }

                    Item {
                        width: parent.width
                        height: elapsed.implicitHeight

                        PanelText {
                            id: elapsed
                            text: StatusIcons.trackTime(root.player?.position ?? 0)
                            color: Theme.foregroundInactive
                            font.pixelSize: 10
                        }

                        PanelText {
                            anchors.right: parent.right
                            text: StatusIcons.trackTime(root.player?.length ?? 0)
                            color: Theme.foregroundInactive
                            font.pixelSize: 10
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    IconButton {
                        iconName: "media-skip-backward"
                        opacity: (root.player?.canGoPrevious ?? false) ? 1 : 0.35
                        onActivated: MediaStatus.previous()
                    }

                    IconButton {
                        iconName: MediaStatus.playing ? "media-playback-pause" : "media-playback-start"
                        opacity: (root.player?.canTogglePlaying ?? false) ? 1 : 0.35
                        onActivated: MediaStatus.toggle()
                    }

                    IconButton {
                        iconName: "media-skip-forward"
                        opacity: (root.player?.canGoNext ?? false) ? 1 : 0.35
                        onActivated: MediaStatus.next()
                    }
                }

                // A choice only when there is one to make.
                Flow {
                    visible: MediaStatus.players.length > 1
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: MediaStatus.players

                        TextButton {
                            required property var modelData
                            text: modelData?.identity ?? ""
                            checked: modelData === MediaStatus.current
                            onActivated: MediaStatus.choose(modelData)
                        }
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    TextButton {
                        visible: root.player?.canRaise ?? false
                        text: `Show ${root.player?.identity ?? "the player"}`
                        iconName: root.player?.desktopEntry ?? ""
                        onActivated: {
                            root.player.raise();
                            root.popoutVisible = false;
                        }
                    }

                    TextButton {
                        text: "Media controls…"
                        iconName: "media-playback-start"
                        onActivated: {
                            PlasmaApplets.open("org.kde.plasma.mediacontroller");
                            root.popoutVisible = false;
                        }
                    }
                }
            }
        }
    }
}
