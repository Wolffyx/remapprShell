// Preview-only stand-in: offscreen has no layer-shell backend, so the real
// EdgeWindow (a PanelWindow) cannot be created. Same properties, no placement.
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

    readonly property string edge: win.bar?.position ?? "bottom"
    readonly property bool horizontal: win.edge === "top" || win.edge === "bottom"

    // Nothing is placed offscreen, so the shift is always zero and the padding
    // is the shadow margin on every side -- which is what the real one reduces
    // to when the window has not been pushed back on screen.
    readonly property int alongShift: 0
    readonly property int padLead: win.shadowMargin
    readonly property int padTrail: win.shadowMargin
    readonly property int padH: 2 * win.shadowMargin
    readonly property int padV: 2 * win.shadowMargin
    readonly property int padTop: win.shadowMargin
    readonly property int padBottom: win.shadowMargin
    readonly property int padLeft: win.shadowMargin
    readonly property int padRight: win.shadowMargin

    readonly property real slotStart: 0
    readonly property real along: 0
    readonly property real away: 0

    function place(): void {}
    function report(): void {}

    color: "transparent"
}
