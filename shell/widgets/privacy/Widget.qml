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
import qs.ui.primitives

BarWidget {
    id: root

    readonly property int size: Math.max(22, Math.round(40 * root.unit))

    readonly property var users: PrivacyStatus.users
    readonly property bool recordingSound: root.users.microphone.length > 0
    readonly property bool vertical: !(root.bar?.horizontal ?? true)

    present: PrivacyStatus.present

    tooltip: [StatusIcons.privacyTooltip(root.users, AudioStatus.micMuted),
              root.recordingSound ? (AudioStatus.micMuted ? "Click to unmute the microphone"
                                                          : "Click to mute the microphone") : ""]
        .filter(s => s).join("\n")

    implicitWidth: Math.max(root.size, icons.implicitWidth + 16)
    implicitHeight: root.vertical ? Math.max(root.size, icons.implicitHeight + 16) : root.size

    // Muting is for the default microphone, as it is in Plasma's indicator:
    // it is the one the icon's state is read from.
    function handleActivate(button) {
        if (button === Qt.MiddleButton || !root.recordingSound)
            return;
        AudioStatus.toggleMicMute();
    }

    BarButton {
        anchors.fill: parent
        thickness: root.bar?.thickness ?? 40
        hovered: root.hovered
        size: root.size
    }

    Grid {
        id: icons
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
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
