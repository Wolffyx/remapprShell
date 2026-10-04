pragma ComponentBehavior: Bound

// The strip you pull the sidebar out by.
//
// KWin's screen edges answer a pointer that merely *reaches* the edge, which
// is how the sidebar was opened before -- and a panel that appears because the
// pointer went to the scrollbar is a panel that opens all day by accident.
// This is the other thing every shell with a sidebar does: a few pixels at the
// very edge that has to be pressed and pulled inwards.
//
// One per screen, so the sidebar comes out of *this* monitor rather than the
// first one. That is the whole reason it exists on every screen rather than
// being a single surface: a layer surface belongs to one output, and the
// output it belongs to is the answer to "which screen did you drag on".
//
// The strip is space of its own. It reserves its width, as a panel does, so a
// maximised window stops short of it and nothing is ever under it to lose a
// press -- the scrollbar at the edge of a browser included. That is how a
// shell drawn with a frame round the screen gets a drag handle for nothing:
// the frame is reserved, and the handle is the frame. Before this the strip
// lay over the edge of whatever was there and took the press off it, under a
// resize cursor that said a window border was there. `sidebar.handleReserves`
// is that old behaviour, for someone who would rather keep the pixels.
//
// Down the whole height of the edge, since nothing is under it: pressed
// anywhere and pulled inwards. `sidebar.handleWidth` is how wide.
//
// It goes deaf -- draws nothing, takes nothing -- while the sidebar is out and
// over a full-screen window, without unmapping: the reserved space goes with
// the surface, and every maximised window on the screen would be resized away
// and back each time. The panel steps aside the same way, for the same reason.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.config
import qs.domain.desktops
import qs.domain.sidebar.cards
import qs.domain.surfaces
import qs.domain.theme
import qs.domain.windows
import qs.domain.windows.events

PanelWindow {
    id: handle

    required property var modelData
    screen: handle.modelData

    readonly property bool leftEdge: Cards.onLeft(ConfigStore.value("sidebar.position", "right"))
    readonly property int strip: Math.max(2, Number(ConfigStore.value("sidebar.handleWidth", 6)))
    readonly property bool reserves: ConfigStore.value("sidebar.handleReserves", true) !== false

    // How far it has to be pulled before the sidebar comes out. Far enough
    // that a click at the edge is not a drag, short enough that the gesture
    // feels answered rather than resisted.
    readonly property int threshold: 28

    // A full-screen window takes the whole monitor whatever is reserved, and
    // the edge is the game's or the video's. By output, as the panel asks.
    readonly property bool fullScreenHere: WindowEvents.fullScreenOn(WindowsService.windows,
                                                                    handle.modelData?.name ?? "",
                                                                    Desktops.currentId)
    readonly property bool deaf: Surfaces.sidebar || handle.fullScreenHere
    readonly property Region _deaf: Region {}

    anchors {
        top: true
        bottom: true
        left: handle.leftEdge
        right: !handle.leftEdge
    }

    // Kept clear of a panel's reserved space either way; reserving its own
    // only while it keeps windows off it.
    exclusiveZone: handle.reserves ? handle.strip : 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: `${Branding.slug}-sidebar-handle`
    color: "transparent"

    implicitWidth: handle.strip

    mask: handle.deaf ? handle._deaf : null

    // A hairline that says there is something here, brighter while the
    // pointer is anywhere on the strip. Ten per cent of an accent is not
    // decoration -- an invisible grab strip is one nobody finds.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: Math.min(180, parent.height * 0.22)
        radius: width / 2
        color: Theme.acc
        visible: !handle.deaf
        opacity: pull.active ? 0.85 : hover.hovered ? 0.55 : 0.18
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    // The ordinary pointer: no resize arrows, which said a window border was
    // there, and nothing to learn -- the hairline brightening says the rest.
    HoverHandler {
        id: hover
    }

    // Pulled inwards: left edge to the right, right edge to the left. The
    // sidebar opens once, when the drag passes the threshold -- not on
    // release, so it comes out under the finger rather than after it.
    DragHandler {
        id: pull

        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        property bool opened: false

        onActiveChanged: if (!active) pull.opened = false

        onTranslationChanged: {
            if (pull.opened || !pull.active)
                return;
            const pulled = handle.leftEdge ? translation.x : -translation.x;
            if (pulled < handle.threshold)
                return;
            pull.opened = true;
            Surfaces.toggleSidebar(handle.screen?.name ?? "");
        }
    }
}
