pragma ComponentBehavior: Bound

// This shell's own notification popups.
//
// Drawn only while this shell serves notifications (notifications.server
// "shell") and really holds the name; otherwise Plasma draws them and this
// is never created. One screen, as the OSD is, in a corner beside the panel.
//
// A top-layer surface with no exclusive zone: it reserves nothing and keeps
// clear of the panel's reserved edge. Top rather than overlay, so a
// full-screen game or video stays above it.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.config
import qs.domain.notifications
import qs.domain.notifications.popups

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property string corner: Popups.corner(ShellNotifications.position,
                                                   ConfigStore.value("panel.position", "bottom"))
    readonly property bool fromBottom: root.corner.startsWith("bottom")

    visible: ShellNotifications.popups.length > 0

    // A centred stack anchors to neither side, and the compositor centres it
    // on that edge.
    anchors {
        top: !root.fromBottom
        bottom: root.fromBottom
        left: root.corner.endsWith("left")
        right: root.corner.endsWith("right")
    }
    margins.top: 20
    margins.bottom: 20
    margins.left: 20
    margins.right: 20

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: `${Branding.slug}-notifications`
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)

    Column {
        id: stack

        width: parent.width
        spacing: 8

        Repeater {
            // Newest nearest the panel: from a bottom corner the stack grows
            // upwards.
            model: root.fromBottom ? ShellNotifications.popups.slice().reverse() : ShellNotifications.popups

            NotificationCard {
                required property var modelData

                width: stack.width
                notification: modelData
            }
        }
    }
}
