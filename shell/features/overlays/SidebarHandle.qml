pragma ComponentBehavior: Bound

// The strip you pull the sidebar out by.
//
// KWin's screen edges answer a pointer that merely *reaches* the edge, which
// is how the sidebar was opened before -- and a panel that appears because the
// pointer went to the scrollbar is a panel that opens all day by accident.
// This is the other thing every shell with a sidebar does: the very edge of
// the screen, pressed and pulled inwards.
//
// One per screen, so the sidebar comes out of *this* monitor rather than the
// first one: a layer surface belongs to one output, and the output it belongs
// to is the answer to "which screen did you drag on".
//
// Push, then pull. The strip lies over the edge of whatever window is there,
// and a press on it is the strip's -- Wayland does not hand it on to the
// window under it, so a strip that was always there took the last pixels of
// every scrollbar against that edge. So it takes nothing at all until the
// pointer is pushed into the edge (SidebarReveal, off KWin's own screen
// edge), then lights up down the whole edge for a moment to be pressed and
// pulled, and goes back to nothing. Only a screen whose edge on that side is
// the outside of the layout has one: a shared edge cannot be pushed into, the
// pointer goes on to the next screen (ShellScreens).
//
// What it takes is the last `sidebar.handleWidth` pixels -- one by default,
// the column the pointer stops in when it is pushed. What it draws is a little
// wider, to be seen.
//
// `sidebar.handleReserves` is the other answer: the strip reserves its own
// width, as a panel does, so nothing is ever under it and it can simply always
// be there -- at the cost of a gap that wide down that edge, which is why it
// is off.
//
// Over a full-screen window on its monitor, and while the sidebar is out, it
// takes and draws nothing -- without unmapping, so a reserved strip keeps its
// space and maximised windows are not resized away and back.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.config
import qs.domain.desktops
import qs.domain.sidebar
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
    readonly property int strip: Math.max(1, Number(ConfigStore.value("sidebar.handleWidth", 1)))
    readonly property bool reserves: ConfigStore.value("sidebar.handleReserves", false) === true

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

    // Pushed into, and not yet let go. A reserved strip is always lit.
    property bool pushed: false
    readonly property bool lit: !handle.deaf && (handle.reserves || handle.pushed)

    readonly property Region _deaf: Region {}
    readonly property Region _edge: Region {
        x: handle.leftEdge ? 0 : handle.width - handle.strip
        y: 0
        width: handle.strip
        height: handle.height
    }

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

    // Wider than what it takes, so the light can be seen; reserved, no wider
    // than the space it keeps.
    implicitWidth: handle.reserves ? handle.strip : Math.max(handle.strip, 4)

    mask: handle.lit ? handle._edge : handle._deaf

    Connections {
        target: SidebarReveal

        function onRevealed() {
            if (handle.deaf || handle.reserves)
                return;
            handle.pushed = true;
            dim.interval = 2000;
            dim.restart();
        }
    }

    // Goes out a moment after the pointer leaves it, or two seconds after the
    // push if it never arrives. Never while it is held.
    Timer {
        id: dim
        onTriggered: {
            if (!hover.hovered && !pull.active)
                handle.pushed = false;
        }
    }

    // The light: down the whole edge, at the very edge.
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        x: handle.leftEdge ? 0 : parent.width - width
        width: Math.min(parent.width, 3)
        radius: width / 2
        color: Theme.acc
        opacity: !handle.lit ? 0 : pull.active ? 0.85 : hover.hovered ? 0.6 : handle.reserves ? 0.18 : 0.45
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hover.hovered || handle.reserves) {
                dim.stop();
                return;
            }
            dim.interval = 700;
            dim.restart();
        }
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

        // Let go: out at once if the sidebar came, and otherwise the way
        // leaving does -- a one-pixel strip is left as soon as the drag
        // starts, so the hover alone would never put it out.
        onActiveChanged: {
            if (pull.active)
                return;
            const opened = pull.opened;
            pull.opened = false;
            if (opened) {
                handle.pushed = false;
                return;
            }
            dim.interval = 700;
            dim.restart();
        }

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
