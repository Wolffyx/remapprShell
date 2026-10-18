pragma ComponentBehavior: Bound

// A snap layout drawn at the shape of a screen, to edit: a click on a zone
// chooses it, and an edge two zones share is dragged to move it. What a
// change makes is SnapEditor's; this draws it and says what was done.
//
// One MouseArea over the whole of it does both, rather than one an edge:
// every step of a drag makes a new tree, and with it new edges -- a handle
// of its own would be destroyed under the pointer at the first step.

import QtQuick
import qs.domain.theme
import qs.domain.windows.snap
import qs.ui.primitives

Item {
    id: root

    // The layout, in layouts.js's format.
    property var tree: SnapEditor.blank()
    // The chosen zone's path (SnapEditor.zones), or [] for none.
    property var selected: []
    // Drawn as a tall screen, 9:16, rather than a wide one.
    property bool tall: false

    signal edited(var tree)
    signal picked(var path)

    readonly property var zones: SnapEditor.zones(root.tree)
    readonly property var edges: SnapEditor.edges(root.tree)

    // How near an edge, in pixels, the pointer takes it.
    readonly property int grab: 7
    readonly property int gap: 3

    // The edge being dragged, as it was at the press, and the tree then:
    // each step moves that edge of that tree, so the steps never add up
    // their rounding.
    property var dragEdge: null
    property var dragTree: null

    implicitHeight: Math.round(root.width * (root.tall ? 16 / 9 : 9 / 16))

    function edgeAt(x, y) {
        return root.edges.find(e => root.nearEdge(e, x / root.width, y / root.height)) ?? null;
    }

    function nearEdge(e, fx, fy) {
        if (e.dir === "h")
            return Math.abs(fx - e.position) * root.width <= root.grab && fy >= e.y && fy <= e.y + e.height;
        return Math.abs(fy - e.position) * root.height <= root.grab && fx >= e.x && fx <= e.x + e.width;
    }

    function zoneAt(x, y) {
        const fx = x / root.width, fy = y / root.height;
        return root.zones.find(z => fx >= z.x && fx < z.x + z.width && fy >= z.y && fy < z.y + z.height) ?? null;
    }

    // What the pointer does, in the canvas's own pixels: functions of their
    // own, so a preview can drive them as the MouseArea does.
    function press(x, y) {
        root.dragEdge = root.edgeAt(x, y);
        root.dragTree = root.tree;
    }

    function drag(x, y) {
        const along = root.dragEdge.dir === "h" ? x / root.width : y / root.height;
        root.edited(SnapEditor.moveEdge(root.dragTree, root.dragEdge, along));
    }

    function release() {
        root.dragEdge = null;
        root.dragTree = null;
    }

    function click(x, y) {
        const z = root.zoneAt(x, y);
        if (z && root.edgeAt(x, y) === null)
            root.picked(z.path);
    }

    function percent(n) {
        return `${Math.round(n * 100)}%`;
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusTiny + 2
        color: Theme.s1
        border.width: 1
        border.color: Theme.out
    }

    Repeater {
        model: root.zones

        delegate: Rectangle {
            id: zone

            required property var modelData
            required property int index

            readonly property bool chosen: SnapEditor.samePath(zone.modelData.path, root.selected)

            x: Math.round(zone.modelData.x * root.width) + root.gap
            y: Math.round(zone.modelData.y * root.height) + root.gap
            width: Math.round((zone.modelData.x + zone.modelData.width) * root.width) - zone.x - root.gap
            height: Math.round((zone.modelData.y + zone.modelData.height) * root.height) - zone.y - root.gap
            radius: Theme.radiusTiny
            color: zone.chosen ? Theme.accC : Theme.s3
            border.width: zone.chosen ? 2 : 1
            border.color: zone.chosen ? Theme.acc : Theme.out

            Column {
                anchors.centerIn: parent
                spacing: 2

                PanelText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: zone.index + 1
                    font.pixelSize: 15
                    font.bold: true
                    color: zone.chosen ? Theme.accCFg : Theme.fg
                }

                PanelText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: zone.width > 64
                    text: `${root.percent(zone.modelData.width)} × ${root.percent(zone.modelData.height)}`
                    font.pixelSize: 11
                    color: zone.chosen ? Theme.accCFg : Theme.mut
                }
            }
        }
    }

    // The edges, a bar on each that thickens under the pointer.
    Repeater {
        model: root.edges

        delegate: Rectangle {
            id: edge

            required property var modelData

            readonly property bool h: edge.modelData.dir === "h"
            readonly property bool lit: mouse.hoverEdge !== null
                && SnapEditor.samePath(mouse.hoverEdge.path, edge.modelData.path)
                && mouse.hoverEdge.index === edge.modelData.index
            readonly property int thick: edge.lit ? 4 : 2
            readonly property real along: (edge.h ? edge.modelData.height * root.height : edge.modelData.width * root.width)

            x: edge.h ? Math.round(edge.modelData.position * root.width) - edge.thick / 2
                      : Math.round(edge.modelData.x * root.width) + (edge.along - edge.width) / 2
            y: edge.h ? Math.round(edge.modelData.y * root.height) + (edge.along - edge.height) / 2
                      : Math.round(edge.modelData.position * root.height) - edge.thick / 2
            width: edge.h ? edge.thick : Math.min(40, edge.along / 3)
            height: edge.h ? Math.min(40, edge.along / 3) : edge.thick
            radius: edge.thick / 2
            color: edge.lit ? Theme.acc : Theme.mut
            opacity: edge.lit ? 1 : 0.6
        }
    }

    MouseArea {
        id: mouse

        property var hoverEdge: null

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: mouse.hoverEdge === null ? Qt.PointingHandCursor
            : mouse.hoverEdge.dir === "h" ? Qt.SplitHCursor : Qt.SplitVCursor

        onPositionChanged: m => {
            if (root.dragEdge === null)
                mouse.hoverEdge = root.edgeAt(m.x, m.y);
            else
                root.drag(m.x, m.y);
        }
        onPressed: m => root.press(m.x, m.y)
        onReleased: root.release()
        onClicked: m => root.click(m.x, m.y)
        onExited: mouse.hoverEdge = null
    }
}
