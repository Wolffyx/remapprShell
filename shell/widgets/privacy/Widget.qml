pragma ComponentBehavior: Bound

// The camera or a microphone, while an application has it.
//
// Plasma's tray shows an icon while anything records, and a click on the
// microphone one mutes it. Under our renderer that icon was gone with the
// tray; this puts it back, the same way round: present only while something
// records, the applications named in the tooltip, a click to mute.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.platform.kde
import qs.ui.controls
import qs.ui.primitives

BarWidget {
    id: root

    readonly property var users: PrivacyStatus.users
    readonly property bool recordingSound: root.users.microphone.length > 0

    present: PrivacyStatus.present

    tooltip: StatusIcons.privacyHint(root.users, AudioStatus.micMuted)

    implicitWidth: Math.max(root.tileSize, icons.implicitWidth + 16)
    implicitHeight: root.barVertical ? Math.max(root.tileSize, icons.implicitHeight + 16) : root.tileSize

    // Muting is for the default microphone, as it is in Plasma's indicator:
    // it is the one the icon's state is read from. A middle click keeps doing
    // it in one press; a left click opens the list, because "something is
    // recording" is only half an answer and the other half is which.
    function handleActivate(button) {
        if (button === Qt.MiddleButton) {
            if (root.recordingSound)
                AudioStatus.toggleMicMute();
            return;
        }
        root.popoutVisible = !root.popoutVisible;
    }

    popout: Component {
        PopoutColumn {
            id: body
            implicitWidth: 300
            spacing: 8

            // One row per application, per device it holds. An application
            // with both is two rows: it is two things it is doing, and one
            // of them can be stopped from here.
            Repeater {
                model: root.users.camera.map(app => ({ kind: "camera", app: app }))
                    .concat(root.users.microphone.map(app => ({ kind: "microphone", app: app })))

                Row {
                    id: user

                    required property var modelData
                    readonly property bool isMic: user.modelData.kind === "microphone"

                    width: body.width
                    spacing: 10

                    PanelIcon {
                        id: userIcon
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 22
                        iconName: user.isMic
                            ? StatusIcons.micIcon(AudioStatus.micVolume, AudioStatus.micMuted)
                            : "camera-on"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - userIcon.width - parent.spacing
                        spacing: 1

                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: user.modelData.app
                        }

                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: user.isMic
                                ? (AudioStatus.micMuted ? "Using the microphone · muted" : "Using the microphone")
                                : "Using the camera"
                            font.pixelSize: 11
                            color: user.isMic && AudioStatus.micMuted ? Theme.mut : Theme.warning
                        }
                    }
                }
            }

            Rectangle {
                visible: root.recordingSound
                width: parent.width
                height: 1
                color: Theme.out
            }

            // The one thing this can actually stop. There is no equivalent for
            // the camera: PipeWire has no mute for a video node, and a camera
            // is released by the application that took it.
            TextButton {
                visible: root.recordingSound
                width: parent.width
                glyph: AudioStatus.micMuted ? "mic" : "mic_off"
                iconName: AudioStatus.micMuted ? "microphone-sensitivity-high" : "microphone-sensitivity-muted"
                text: AudioStatus.micMuted ? "Unmute the microphone" : "Mute the microphone"
                onActivated: AudioStatus.toggleMicMute()
            }

            TextButton {
                width: parent.width
                glyph: "tune"
                iconName: "preferences-desktop-sound"
                text: "Sound settings…"
                onActivated: {
                    PlasmaApplets.openSettings("kcm_pulseaudio");
                    root.popoutVisible = false;
                }
            }
        }
    }

    BarButton {
        anchors.fill: parent
        thickness: root.barThickness
        hovered: root.hovered
        active: root.popoutVisible
        size: root.tileSize
    }

    Grid {
        id: icons
        anchors.centerIn: parent
        columns: root.barVertical ? 1 : 2
        spacing: 4

        Glyph {
            visible: root.users.camera.length > 0
            name: "videocam"
            fallback: "camera-on"
            size: root.panelIconSize
            color: Theme.warning
        }

        Glyph {
            visible: root.recordingSound
            name: AudioStatus.micMuted ? "mic_off" : "mic"
            fallback: AudioStatus.micMuted ? "microphone-sensitivity-muted" : "microphone-sensitivity-high"
            size: root.panelIconSize
            color: Theme.warning
        }
    }
}
