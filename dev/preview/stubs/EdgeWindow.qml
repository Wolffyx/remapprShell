// Preview-only stand-in: offscreen has no layer-shell backend, so the real
// EdgeWindow (a PanelWindow) cannot be created. Same properties, and the same
// placement once the bar says how big its screen is.
//
// "Same properties" is the whole contract, and it had drifted: the real
// EdgeWindow gained `align` and the padding it derives from the shadow margin
// when placement was reworked, and this did not. A property the stub lacks is
// not a warning -- the type fails to load, so WidgetSlot fails, so the panel
// fails, and every offscreen render of the panel died with
// "Cannot assign to non-existent property align". That is the project's main
// way to look at the panel without a screen, and it had been dark.
import QtQuick
import Quickshell
import qs.domain.panel

FloatingWindow {
    id: win
    required property Item slot
    required property var bar
    property string label: ""
    property real centre: 0
    property int gap: 12
    property int shadowMargin: 0
    property int edgeMargin: 12
    property string align: "centre"
    property bool tail: false

    readonly property int reach: Placement.reach(win.gap, win.shadowMargin)
    readonly property int padNear: win.tail ? win.reach : win.shadowMargin

    readonly property string edge: win.bar?.position ?? "bottom"
    readonly property bool horizontal: win.edge === "top" || win.edge === "bottom"

    // The screen, when the target hands the bar one -- `screenObject: ({ width,
    // height })` -- measured the way the real window measures it. With none,
    // nothing is placed: the shift is zero and the padding is the shadow margin
    // on every side, which is what every target drew before this could place.
    readonly property real screenLength: win.horizontal ? (win.bar?.screenObject?.width ?? 0)
                                                        : (win.bar?.screenObject?.height ?? 0)
    readonly property bool placed: win.screenLength > 0

    property real slotStart: 0

    function place(): void {
        if (!win.placed)
            return;
        const p = win.slot.mapToItem(null, 0, 0);
        win.slotStart = win.horizontal ? p.x : p.y;
    }
    function report(): void {}

    readonly property real along: !win.placed ? 0 : Placement.along(
        win.align, win.slotStart, win.centre,
        win.horizontal ? win.implicitWidth : win.implicitHeight,
        win.screenLength, win.shadowMargin, win.edgeMargin)

    readonly property int placedAlong: Math.round(win.along)

    readonly property int alongShift: !win.placed ? 0 : Placement.shift(
        win.align, win.slotStart, win.centre,
        win.horizontal ? win.implicitWidth : win.implicitHeight,
        win.screenLength, win.shadowMargin, win.edgeMargin)

    readonly property real away: Placement.away(
        win.bar?.extent ?? win.bar?.thickness ?? 0, win.gap, win.shadowMargin, win.padNear)

    readonly property int padLead: win.shadowMargin + win.alongShift
    readonly property int padTrail: win.shadowMargin - win.alongShift
    readonly property int padH: win.horizontal ? 2 * win.shadowMargin : win.shadowMargin + win.padNear
    readonly property int padV: win.horizontal ? win.shadowMargin + win.padNear : 2 * win.shadowMargin
    readonly property int padTop: win.horizontal ? (win.edge === "top" ? win.padNear : win.shadowMargin) : win.padLead
    readonly property int padBottom: win.horizontal ? (win.edge === "bottom" ? win.padNear : win.shadowMargin) : win.padTrail
    readonly property int padLeft: win.horizontal ? win.padLead : (win.edge === "left" ? win.padNear : win.shadowMargin)
    readonly property int padRight: win.horizontal ? win.padTrail : (win.edge === "right" ? win.padNear : win.shadowMargin)

    onVisibleChanged: if (win.visible) win.place()

    // What WidgetSlot draws in the window lands in here rather than straight
    // in the window, so a target can take a picture of it: a window's own
    // content item was not made by QML and refuses `grabToImage`.
    //
    // At the size the window is asked to be, rather than the size it is. An
    // offscreen floating window keeps the size it was first shown at, and a
    // popout whose contents grow once they have loaded -- the volume's list
    // of devices -- was drawn squashed into it, and placed for the size it
    // had asked for.
    default property alias content: drawn.data
    readonly property Item drawing: drawn

    Item {
        id: drawn
        width: win.implicitWidth
        height: win.implicitHeight
    }

    color: "transparent"
}
