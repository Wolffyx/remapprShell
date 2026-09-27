// Sidebar: this shell's own, from a button.
//
// The sidebar had no affordance at all. It could be opened over IPC and by a
// shortcut, and a shortcut is not discoverable -- nothing on screen said the
// sidebar existed, which is how it came to be reported as missing rather than
// as unbound.
//
// It toggles through Surfaces, the same call the shortcut and `rmpr sidebar`
// make, so the button and the key cannot behave differently. Named for the
// screen it sits on, so the sidebar opens on the monitor whose panel was
// clicked rather than on whichever one asked last.

import QtQuick
import qs.ui.primitives
import qs.domain.surfaces

BarWidget {
    id: root

    wantsHover: true
    tooltip: Surfaces.sidebar ? "Close the sidebar" : "Sidebar"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function handleActivate(button) {
        Surfaces.toggleSidebar(root.screenName);
    }

    BarButton {
        id: button
        thickness: root.barThickness
        hovered: root.hovered
        // It slides in from the right, so the glyph points the way it comes.
        glyph: "dock_to_left"
        fallback: "sidebar-expand-left"
        glyphSize: Math.max(17, Math.round(22 * root.unit))
    }
}
