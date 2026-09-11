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

    readonly property var users: PrivacyStatus.users
    readonly property bool recordingSound: root.users.microphone.length > 0
    readonly property bool vertical: !(root.bar?.horizontal ?? true)

    present: PrivacyStatus.present

    tooltip: [StatusIcons.privacyTooltip(root.users, AudioStatus.micMuted),
              root.recordingSound ? (AudioStatus.micMuted ? "Click to unmute the microphone"
                                                          : "Click to mute the microphone") : ""]
        .filter(s => s).join("\n")

    implicitWidth: Math.max(24, icons.implicitWidth + 6)
    implicitHeight: Math.max(24, icons.implicitHeight + 6)

    // Muting is for the default microphone, as it is in Plasma's indicator:
    // it is the one the icon's state is read from.
    function handleActivate(button) {
        if (button === Qt.MiddleButton || !root.recordingSound)
            return;
        AudioStatus.toggleMicMute();
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: hover.hovered ? PlasmaColors.hoverBackground : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        // Only `columns` is set -- see ZoneRow. A hidden icon takes no slot.
        Grid {
            id: icons
            anchors.centerIn: parent
            columns: root.vertical ? 1 : 2
            spacing: 4

            PanelIcon {
                visible: root.users.camera.length > 0
                implicitSize: 18
                iconName: "camera-on"
            }

            PanelIcon {
                visible: root.recordingSound
                implicitSize: 18
                iconName: AudioStatus.micMuted ? "microphone-sensitivity-muted" : "microphone-sensitivity-high"
            }
        }

        HoverHandler { id: hover }
    }
}
