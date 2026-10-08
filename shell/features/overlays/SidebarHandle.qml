pragma ComponentBehavior: Bound

// The grip you pull the sidebar out by.
//
// KWin's screen edges answer a pointer that merely *reaches* the edge, which
// is how the sidebar was opened before -- and a panel that appears because the
// pointer went to the scrollbar is a panel that opens all day by accident.
// This is the other thing every shell with a sidebar does: the very edge of
// the screen, pressed and pulled inwards -- and the sidebar comes out under
// the pointer as it is pulled, and goes back if it is let go too soon.
//
// One per screen, so the sidebar comes out of *this* monitor rather than the
// first one: a layer surface belongs to one output, and the output it belongs
// to is the answer to "which screen did you drag on".
//
// Push, then pull. The grip lies over the edge of whatever window is there,
// and a press on it is the grip's -- Wayland does not hand it on to the
// window under it. So it takes nothing at all until the pointer is pushed
// against the edge and rests there (SidebarReveal, off the KWin script that
// follows that column, which also says where), then lights up *there*, a
// short grip under the pointer, for a
// moment, and goes back to nothing. What takes a press is that grip and a
// little either side of it, `sidebar.handleWidth` pixels deep -- one by
// default, the column the pointer stops in when it is pushed. It used to be
// the whole height of the edge, lit from end to end: more than anybody needed
// to see, and the last pixels of every scrollbar down that edge for as long
// as it was lit. Every screen has one, the same way: against the outside of
// the layout the pointer cannot go further, and against another screen KWin's
// edge barrier holds it in the last column a moment before it crosses.
//
// `sidebar.handleReserves` is the other answer: the strip reserves its own
// width, as a panel does, so nothing is ever under it and it can simply always
// be there, the whole height, with the grip wherever the pointer is on it --
// at the cost of a gap that wide down that edge, which is why it is off.
//
// Over a full-screen window on its monitor, and while the sidebar is out, it
// takes and draws nothing -- without unmapping, so a reserved strip keeps its
// space and maximised windows are not resized away and back. KWin keeps its
// edge quiet over a full-screen window too, so a game is never asked to share
// its edge.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.config
import qs.domain.desktops
import qs.domain.sidebar
import qs.domain.sidebar.cards
import qs.domain.sidebar.gesture
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

    // How far the sidebar moves to be all the way out, which is how far a
    // pull has to go to bring it all the way.
    readonly property int travel: Math.max(280, Number(ConfigStore.value("sidebar.width", 396)))
        + Math.max(0, Number(ConfigStore.value("sidebar.margin", 16)))

    // The grip as drawn, and how much either side of it takes a press too:
    // enough not to have to hit it exactly, little enough to leave the rest
    // of the edge alone.
    readonly property int gripLength: 64
    readonly property int slack: 28

    // A full-screen window takes the whole monitor whatever is reserved, and
    // the edge is the game's or the video's. By output, as the panel asks.
    readonly property bool fullScreenHere: WindowEvents.fullScreenOn(WindowsService.windows,
                                                                    handle.modelData?.name ?? "",
                                                                    Desktops.currentId)

    // Not while it is held: a pull keeps the press it started with until it
    // is let go, the sidebar out under it or not.
    readonly property bool deaf: handle.fullScreenHere || (Surfaces.sidebarShown && !pull.active)

    // Pushed into, and not yet let go. A reserved strip is always lit.
    property bool pushed: false
    readonly property bool lit: !handle.deaf && (handle.reserves || handle.pushed)

    // Where the pointer was pushed in, in this surface's coordinates; -1 is
    // the middle. A reserved strip has the pointer on it, and follows it.
    property real gripY: -1
    readonly property real gripCentre: handle.reserves && hover.hovered
        ? Gesture.gripCentre(hover.point.position.y, 0, handle.height, handle.gripLength)
        : handle.gripY >= 0 ? handle.gripY : Math.round(handle.height / 2)

    readonly property var _band: Gesture.band(handle.gripCentre, handle.gripLength, handle.slack, handle.height)
    readonly property Region _deaf: Region {}
    readonly property Region _edge: Region {
        x: handle.leftEdge ? 0 : handle.width - handle.strip
        y: handle.reserves ? 0 : handle._band.y
        width: handle.strip
        height: handle.reserves ? handle.height : handle._band.height
    }

    anchors {
        top: true
        bottom: true
        left: handle.leftEdge
        right: !handle.leftEdge
    }

    // Reserved, it keeps windows off exactly its width (Auto). Otherwise it
    // ignores every other zone and runs the whole height of the screen, so
    // its coordinates are the screen's and the grip goes where KWin says the
    // pointer was.
    exclusionMode: handle.reserves ? ExclusionMode.Auto : ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: `${Branding.slug}-sidebar-handle`
    color: "transparent"

    // Wider than what it takes, so the grip can be seen; reserved, no wider
    // than the space it keeps.
    implicitWidth: handle.reserves ? handle.strip : Math.max(handle.strip, 6)

    mask: handle.lit ? handle._edge : handle._deaf

    Connections {
        target: SidebarReveal

        function onRevealed(output: string, x: real, y: real): void {
            if (handle.deaf || handle.reserves)
                return;
            if (output.length > 0 && output !== (handle.screen?.name ?? ""))
                return;
            handle.gripY = Gesture.gripCentre(y, handle.screen?.y ?? 0, handle.height, handle.gripLength);
            handle.pushed = true;
            dim.interval = 1500;
            dim.restart();
        }
    }

    // Goes out a moment after the pointer leaves it, or a moment and a half
    // after the push if it never arrives. Never while it is held.
    Timer {
        id: dim
        onTriggered: {
            if (!hover.hovered && !pull.active)
                handle.pushed = false;
        }
    }

    // How strongly the grip shows: not at all until it is lit, and not once
    // the sidebar follows the pull -- the sidebar is the answer then.
    readonly property real _glow: !handle.lit || pull.following ? 0
        : pull.active ? 1 : hover.hovered ? 0.95 : handle.reserves ? 0.3 : 0.8

    // The grip: one short bar at the very edge, where the pointer is. A
    // darker rim rather than a light around it -- a pale halo beside the bar
    // read as a second bar -- so it shows over a pale scrollbar as well as a
    // dark one.
    Rectangle {
        id: grip
        width: Math.min(parent.width, 5)
        height: hover.hovered || pull.active ? handle.gripLength + 16 : handle.gripLength
        radius: width / 2
        x: handle.leftEdge ? 0 : parent.width - width
        y: Math.round(handle.gripCentre - height / 2)
        color: Theme.acc
        border.width: 1
        border.color: Qt.darker(Theme.acc, 1.35)
        opacity: handle._glow
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hover.hovered || handle.reserves) {
                dim.stop();
                return;
            }
            dim.interval = 600;
            dim.restart();
        }
    }

    // Pulled inwards: left edge to the right, right edge to the left. Past
    // the dead zone the sidebar comes out under the pointer and follows it;
    // let go, it stays if it was more than a third of the way out or flicked
    // inwards, and goes back to its edge otherwise.
    DragHandler {
        id: pull

        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        property bool following: false
        property real progress: 0

        onTranslationChanged: {
            if (!pull.active)
                return;
            const pulled = Gesture.inward(pull.translation.x, handle.leftEdge);
            if (!pull.following && pulled < Gesture.deadZone)
                return;
            pull.following = true;
            pull.progress = Gesture.progress(pulled, handle.travel);
            Surfaces.pullSidebar(handle.screen?.name ?? "", pull.progress);
        }

        // Let go: the sidebar settles one way or the other if it came, and
        // otherwise the grip goes out the way leaving does -- a one-pixel
        // strip is left as soon as the drag starts, so the hover alone would
        // never put it out.
        onActiveChanged: {
            if (pull.active) {
                dim.stop();
                return;
            }
            if (!pull.following) {
                dim.interval = 600;
                dim.restart();
                return;
            }
            const velocity = Gesture.inward(pull.centroid.velocity.x, handle.leftEdge);
            Surfaces.releaseSidebar(Gesture.settlesOpen(pull.progress, velocity));
            pull.following = false;
            pull.progress = 0;
            handle.pushed = false;
        }
    }
}
