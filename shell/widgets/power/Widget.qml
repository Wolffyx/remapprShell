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

    tooltip: ({ promptLogout: "Log out", promptReboot: "Restart", promptShutDown: "Shut down" })[root.action]
             ?? "Log out, restart or shut down"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function handleActivate(button) {
        prompt.running = false;
        prompt.running = true;
    }

    readonly property Process _prompt: Process {
        id: prompt
        command: ["busctl", "--user", "call", "org.kde.LogoutPrompt", "/LogoutPrompt",
                  "org.kde.LogoutPrompt", root.action]
    }

    BarButton {
        id: button
        thickness: root.bar?.thickness ?? 40
        hovered: root.hovered
        size: Math.max(22, Math.round(40 * root.unit))
        glyph: "power_settings_new"
        fallback: "system-shutdown"
    }
}
