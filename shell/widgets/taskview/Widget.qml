// Task view: KWin's Overview, from a button.
//
// KWin draws it, with the window thumbnails this shell cannot have (see the
// handoff's note on thumbnails). The button asks for it the way the keyboard
// shortcut does -- kglobalaccel invokes KWin's own action -- so the button and
// Meta+W cannot behave differently.

import QtQuick
import qs.platform.kde
import qs.ui.primitives

BarWidget {
    id: root

    readonly property string effect: root.widgetConfig?.effect ?? "Overview"

    wantsHover: true

    tooltip: ({ "Overview": "Task view", "Grid View": "Virtual desktops", "Expose": "Windows on this desktop", "ExposeAll": "All windows" })[root.effect] ?? "Task view"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function handleActivate(button) {
        Dbus.invokeShortcut(root.effect);
    }

    BarButton {
        id: button
        thickness: root.bar?.thickness ?? 40
        hovered: root.hovered
        glyph: "grid_view"
        fallback: "view-app-grid"
        glyphSize: Math.max(17, Math.round(22 * root.unit))
    }
}
