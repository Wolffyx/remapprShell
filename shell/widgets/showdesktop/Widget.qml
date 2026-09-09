// The thin strip at the far end of the panel that shows the desktop.
//
// KWin already implements showing the desktop, so this only asks it to. The
// widget is the affordance, not the mechanism.

import QtQuick
import Quickshell.Io
import qs.ui.primitives
import qs.domain.theme

BarWidget {
    id: root

    readonly property int stripWidth: root.widgetConfig?.width ?? 8

    wantsHover: true

    implicitWidth: root.bar?.horizontal ? root.stripWidth : root.bar?.thickness ?? root.stripWidth
    implicitHeight: root.bar?.horizontal ? (root.bar?.thickness ?? 24) : root.stripWidth

    function handleActivate(button) {
        toggle.running = false;
        toggle.running = true;
    }

    property bool showing: false

    readonly property Process _toggle: Process {
        id: toggle
        command: ["busctl", "--user", "call", "org.kde.KWin", "/KWin", "org.kde.KWin",
                  "showDesktop", "b", root.showing ? "false" : "true"]
        onRunningChanged: if (!running) root.showing = !root.showing
    }

    Rectangle {
        anchors.fill: parent
        color: hover.hovered ? PlasmaColors.hoverBackground : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        // A hairline so the strip is discoverable rather than an invisible
        // region the user has to know about.
        Rectangle {
            anchors.centerIn: parent
            width: root.bar?.horizontal ? 1 : parent.width * 0.5
            height: root.bar?.horizontal ? parent.height * 0.5 : 1
            color: PlasmaColors.alpha(PlasmaColors.foreground, 0.3)
        }

        HoverHandler { id: hover }
    }
}
