// A window beside the panel, pointing at one slot on it: a widget's popout,
// or its tooltip.
//
// Placement lives here once, so the two cannot disagree and every panel edge
// is handled the same way. The popout used to place itself and assumed a
// horizontal panel: on a panel down the side of the screen it opened at the
// bottom, nowhere near the widget that asked for it.
//
// A layer surface rather than an xdg popup -- see WidgetSlot for why.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.panel

PanelWindow {
    id: win

    required property Item slot
    required property var bar

    // What this is, for the log: "popout 'volume'".
    property string label: ""

    // The point to centre on, measured along the panel from the slot's start.
    property real centre: 0

    // Distance from the panel's inner edge.
    property int gap: 12

    // Transparent room around what is drawn, for its shadow. The window is
    // placed so that what is drawn, not the window, sits `gap` from the panel
    // and at least `edgeMargin` from the ends of the screen.
    property int shadowMargin: 0
    property int edgeMargin: 12

    // How the window lines up with the slot along the panel: "centre" or
    // "start". See Placement.
    property string align: "centre"

    // Whether what is drawn hangs from the slot by a neck across the gap,
    // rather than standing clear of the panel (Tail; `popoutTail` on the
    // widget). The window then reaches all the way to the panel's edge: the
    // room on that side is the whole distance to the card, `reach`, rather
    // than the shadow's margin. The card itself lands where it always does.
    property bool tail: false

    // How far what is drawn sits clear of the panel's edge.
    readonly property int reach: Placement.reach(win.gap, win.shadowMargin)
    readonly property int padNear: win.tail ? win.reach : win.shadowMargin

    // Along the panel the room is lopsided wherever the window has been pushed
    // back on screen: the card keeps its place over the widget and the shadow
    // gives up the room it could not have had anyway. See Placement.shift.
    readonly property int padLead: win.shadowMargin + win.alongShift
    readonly property int padTrail: win.shadowMargin - win.alongShift

    // The totals, which the shift cannot change: it moves the card within the
    // window, it does not resize it. Sizes are taken from these rather than
    // from the four margins, because a size that depended on the shift would
    // depend on itself -- the shift is worked out from the size.
    //
    // The room is the same on every side. It was once capped on the side
    // facing the panel, to stop the window reaching back over it; that cut the
    // shadow off square along the bottom, which is what "the bottom-left
    // corner is straight, not round" was. The gap carries that job now --
    // Placement.away. The one exception is a window with a tail, which needs
    // the whole gap on the panel's side for the neck (`padNear`).
    readonly property int padH: win.horizontal ? 2 * win.shadowMargin : win.shadowMargin + win.padNear
    readonly property int padV: win.horizontal ? win.shadowMargin + win.padNear : 2 * win.shadowMargin

    readonly property int padTop: win.horizontal ? (win.edge === "top" ? win.padNear : win.shadowMargin) : win.padLead
    readonly property int padBottom: win.horizontal ? (win.edge === "bottom" ? win.padNear : win.shadowMargin) : win.padTrail
    readonly property int padLeft: win.horizontal ? win.padLead : (win.edge === "left" ? win.padNear : win.shadowMargin)
    readonly property int padRight: win.horizontal ? win.padTrail : (win.edge === "right" ? win.padNear : win.shadowMargin)

    readonly property string edge: win.bar?.position ?? "bottom"
    readonly property bool horizontal: win.edge === "top" || win.edge === "bottom"

    // Where the slot starts along the panel, in screen coordinates -- the panel
    // spans its edge, so a position within it is a position on the screen.
    //
    // Taken when the window is shown, never bound. `mapToItem` is a function
    // call, so a binding on it depends on nothing and is evaluated exactly
    // once: when the slot is created, before the zone has laid it out. That
    // left it at 0, and every popout on the panel opened against the screen's
    // left edge, whichever widget it came from.
    property real slotStart: 0

    function place() {
        const p = win.slot.mapToItem(null, 0, 0);
        win.slotStart = win.horizontal ? p.x : p.y;
    }

    readonly property real along: Placement.along(
        win.align, win.slotStart, win.centre,
        win.horizontal ? win.implicitWidth : win.implicitHeight,
        win.horizontal ? (win.screen?.width ?? 0) : (win.screen?.height ?? 0),
        win.shadowMargin, win.edgeMargin)

    // Where the window actually is along the panel, in whole pixels. The
    // margin below takes `along` and rounds it -- margins are whole pixels,
    // and a value type rounds where a plain int property would truncate -- so
    // this is that same number, for anything drawn to line up with the screen
    // rather than with the window (WidgetSlot's tail).
    readonly property int placedAlong: Math.round(win.along)

    readonly property int alongShift: Placement.shift(
        win.align, win.slotStart, win.centre,
        win.horizontal ? win.implicitWidth : win.implicitHeight,
        win.horizontal ? (win.screen?.width ?? 0) : (win.screen?.height ?? 0),
        win.shadowMargin, win.edgeMargin)

    readonly property real away: Placement.away(
        win.bar?.extent ?? win.bar?.thickness ?? 0, win.gap, win.shadowMargin, win.padNear)

    // Where it went, for whoever is working out why a window is somewhere
    // unexpected -- which is how the placement bug above was found. Called
    // once the contents have had a chance to size the window.
    function report() {
        if (win.visible)
            Log.debug("panel", `${win.label} on ${win.screen?.name}, ${win.edge} edge: ${Math.round(win.along)} along, ${win.away} away, ${win.implicitWidth}x${win.implicitHeight}`);
    }

    screen: win.bar?.screenObject ?? null

    // Against the panel's edge, and along it from the start of the screen.
    //
    // The linter cannot resolve the grouped `margins` property on a panel
    // window and warns about it; the property is real and works at runtime.
    anchors {
        top: win.edge === "top" || !win.horizontal
        bottom: win.edge === "bottom"
        left: win.edge === "left" || win.horizontal
        right: win.edge === "right"
    }
    margins.top: win.edge === "top" ? win.away : (win.horizontal ? 0 : win.along)
    margins.bottom: win.edge === "bottom" ? win.away : 0
    margins.left: win.edge === "left" ? win.away : (win.horizontal ? win.along : 0)
    margins.right: win.edge === "right" ? win.away : 0

    // The panel already reserves its strip; this must not reserve another.
    exclusionMode: ExclusionMode.Ignore

    // The top layer, with the panel and the surface that closes a popout when
    // the screen around it is clicked.
    //
    // Not the overlay layer, which is above everything a compositor draws --
    // including a full-screen window. A popout there covers Spectacle's region
    // selector, a full-screen game and a video, which is how it was reported.
    // The top layer is what a panel wants: above ordinary windows, and out of
    // the way of a window that has asked for the whole screen.
    //
    // Sharing a layer with the closing surface means the two stack in the
    // order they were mapped, so the popout is mapped a turn *after* it has
    // told PanelModel it is open -- see WidgetSlot. Mapping both in one turn
    // is what the overlay layer used to paper over.
    WlrLayershell.layer: WlrLayer.Top
    color: "transparent"

    onVisibleChanged: {
        if (win.visible) {
            win.place();
            Qt.callLater(win.report);
        }
    }

    // A slot that moves while this is open -- a tray icon appearing before it
    // -- takes the window with it.
    Connections {
        target: win.slot
        function onXChanged() { if (win.visible) win.place(); }
        function onYChanged() { if (win.visible) win.place(); }
    }
}
