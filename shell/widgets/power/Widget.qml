// Session control.
//
// Opens Plasma's own logout prompt rather than reimplementing one -- it
// already handles inhibitors, unsaved-work warnings and the session manager --
// or, with session.prompt "shell", the shell's session screen, which ends the
// session through the same session manager.

import QtQuick
import qs.domain.session
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

    // Plasma's prompt, or the shell's session screen: Session decides, from
    // session.prompt.
    function handleActivate(button) {
        Session.prompt(root.action);
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
