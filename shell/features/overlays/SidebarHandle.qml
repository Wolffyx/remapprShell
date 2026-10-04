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
// It reserves nothing and takes no keyboard. What it does take is a press on
// the edge, and only where it is drawn: the surface is the pill and nothing
// else, `sidebar.handleLength` long and placed by `sidebar.handleAlign`. It
// used to run the full height of the edge with a pill drawn in the middle, and
// every pixel of that took the press -- off the scrollbar of every window
// against that edge, and off a full-screen one too. `sidebar.handleWidth` is
// how deep it is, `sidebar.trigger` turns it off in favour of KWin's edge or
// of nothing.
//
// And it steps aside over a full-screen window, as the panel does: a game or
// a video owns its edges. `sidebar.handleStepsAside` widens that to any
// window that reaches the edge, for someone who keeps a maximised window's
// scrollbar there and opens the sidebar by key.

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
    readonly property string align: ConfigStore.value("sidebar.handleAlign", "center")

    // Never more than most of the screen: past that it is the full-height
    // strip again, taking the press from everything along the edge.
    readonly property int span: Math.min(Math.max(40, Number(ConfigStore.value("sidebar.handleLength", 180))),
                                         Math.round((handle.modelData?.height ?? 1080) * 0.6))

    // How far it has to be pulled before the sidebar comes out. Far enough
    // that a click at the edge is not a drag, short enough that the gesture
    // feels answered rather than resisted.
    readonly property int threshold: 28

    // A full-screen window on this monitor always sends it away; with
    // "window", so does any window reaching into the strip. By output for the
    // one and by geometry for the other, as the panel asks the same two
    // questions (Panel.qml).
    readonly property bool covered: {
        const windows = WindowsService.windows;
        if (WindowEvents.fullScreenOn(windows, handle.modelData?.name ?? "", Desktops.currentId))
            return true;
        if (ConfigStore.value("sidebar.handleStepsAside", "fullscreen") !== "window")
            return false;
        const s = handle.modelData;
        return WindowEvents.reachesEdge(windows, Desktops.currentId,
                                        { x: s?.x ?? 0, y: s?.y ?? 0, width: s?.width ?? 0, height: s?.height ?? 0 },
                                        handle.leftEdge ? "left" : "right", handle.strip);
    }

    // Neither top nor bottom is "center": layer shell centres a surface on an
    // axis it is not anchored to.
    anchors {
        left: handle.leftEdge
        right: !handle.leftEdge
        top: handle.align === "top"
        bottom: handle.align === "bottom"
    }

    // Kept clear of a panel's reserved space rather than drawn under it, now
    // that it is short enough to sit at one end of the edge.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: `${Branding.slug}-sidebar-handle`
    color: "transparent"

    implicitWidth: handle.strip
    implicitHeight: handle.span

    // Nothing to grab while the sidebar is already out: the sidebar's own
    // close button and Escape put it away, and a handle under it would take
    // the press meant for the card.
    visible: !Surfaces.sidebar && !handle.covered

    // A hairline that says there is something here, brighter under the
    // pointer. Ten per cent of an accent is not decoration -- an invisible
    // grab strip is one nobody finds.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.acc
        opacity: pull.active ? 0.85 : hover.hovered ? 0.55 : 0.18
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    // A hand, not the resize arrows: this is something you take hold of, and
    // the arrows said a window border was there, which is what the edge of a
    // maximised window already says.
    HoverHandler {
        id: hover
        cursorShape: Qt.OpenHandCursor
    }

    // Pulled inwards: left edge to the right, right edge to the left. The
    // sidebar opens once, when the drag passes the threshold -- not on
    // release, so it comes out under the finger rather than after it.
    DragHandler {
        id: pull

        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        cursorShape: Qt.ClosedHandCursor

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
