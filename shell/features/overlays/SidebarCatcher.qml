pragma ComponentBehavior: Bound

// A click anywhere off the sidebar puts it away, as a menu's does.
//
// A layer surface has no popup grab to do that for it, so this is a
// transparent surface over the rest of the screen -- one per screen, so a
// click on the other monitor closes it as well -- that takes the press and
// closes the sidebar. The click goes no further: Wayland cannot hand it on to
// the window underneath, and Plasma's own popups take the same click. That is
// the trade, and why it is a setting (`sidebar.closeOnClickOutside`): off, the
// windows around the sidebar keep working while it is up.
//
// Mapped only while the sidebar is open -- not while a pull is bringing it out
// or while it slides away -- so it costs nothing the rest of the time. On the
// top layer, under the sidebar, which is on the overlay layer: two layers, so
// which was mapped first cannot put this over the card (the race the panel's
// own catcher is mapped from the start to avoid). It keeps clear of the
// panel's reserved space, so the panel's sidebar button still toggles it and
// every other widget still works. Under a full-screen window, as everything on
// the top layer is: there, Escape, the close button or the key put it away.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.surfaces

PanelWindow {
    id: catcher

    required property var modelData
    screen: catcher.modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: `${Branding.slug}-sidebar-catcher`
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: Surfaces.closeSidebar()
    }
}
