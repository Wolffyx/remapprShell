// Preview-only stand-in: offscreen has no layer-shell backend, so the real
// EdgeWindow (a PanelWindow) cannot be created. Same properties, no placement.
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
    readonly property string edge: win.bar?.position ?? "bottom"
    readonly property bool horizontal: win.edge === "top" || win.edge === "bottom"
    color: "transparent"
}
