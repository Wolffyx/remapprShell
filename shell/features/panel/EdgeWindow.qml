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

PanelWindow {
    id: win

    required property Item slot
    required property var bar

    // What this is, for the log: "popout 'volume'".
    property string label: ""

    // The point to centre on, measured along the panel from the slot's start.
    property real centre: 0

    // Distance from the panel's inner edge.
    property int gap: 4

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

    // Centred on what the slot pointed at, then kept on screen: a window for a
    // widget near either end would otherwise run off it.
    readonly property real along: {
        const size = win.horizontal ? win.implicitWidth : win.implicitHeight;
        const extent = win.horizontal ? (win.screen?.width ?? 0) : (win.screen?.height ?? 0);
        const wanted = win.slotStart + win.centre - size / 2;
        return Math.max(8, Math.min(wanted, Math.max(8, extent - size - 8)));
    }

    readonly property real away: (win.bar?.thickness ?? 0) + win.gap

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

    // The overlay layer, above the top one. The surface that closes a popout
    // when the screen around it is clicked (Panel.qml) is on the top layer,
    // and the popout has to be above it: two surfaces on one layer stack in
    // the order they were mapped, and both are mapped at the same moment.
    WlrLayershell.layer: WlrLayer.Overlay
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
