// Session control.
//
// Opens Plasma's own logout prompt rather than reimplementing one. It already
// handles inhibitors, unsaved-work warnings and the session manager -- all
// things a hand-rolled dialog gets wrong.

import QtQuick
import Quickshell.Io
import qs.ui.primitives
import qs.domain.theme

BarWidget {
    id: root

    readonly property string action: root.widgetConfig?.action ?? "promptAll"

    wantsHover: true

    implicitWidth: 24
    implicitHeight: 24

    function handleActivate(button) {
        prompt.running = false;
        prompt.running = true;
    }

    readonly property Process _prompt: Process {
        id: prompt
        command: ["busctl", "--user", "call", "org.kde.LogoutPrompt", "/LogoutPrompt",
                  "org.kde.LogoutPrompt", root.action]
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: hover.hovered ? PlasmaColors.hoverBackground : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        PanelIcon {
            anchors.centerIn: parent
            implicitSize: 18
            iconName: "system-shutdown"
        }

        HoverHandler { id: hover }
    }
}
