pragma ComponentBehavior: Bound

// How the panel is drawn, inside whatever window holds it.
//
//   full      a strip along the whole edge, with a hairline on its inner side
//   floating  a rounded bar held clear of the edge, with a shadow
//   islands   no bar at all: each zone is a rounded island of its own
//
// An Item rather than part of the window, so it can be drawn anywhere -- an
// offscreen picture of the panel is this, in an ordinary window. `bar` is the
// panel (Panel.qml), and `shape` the region that is actually drawn: the window
// takes the pointer only there, and blurs what is behind only there.

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.domain.theme

Item {
    id: root

    required property var bar

    readonly property string style: root.bar.style
    readonly property bool horizontal: root.bar.horizontal
    readonly property string position: root.bar.position
    readonly property int thickness: root.bar.thickness
    readonly property int gap: root.bar.edgeGap
    readonly property real unit: root.thickness / 64

    // Along the edge, a floating bar and islands stop short of the corners.
    readonly property int inset: root.style === "full" ? 0 : 18
    // Inside the bar, before the first widget.
    readonly property int pad: root.style === "full" ? 12 : root.style === "floating" ? 10 : 0
    // Around the widgets of an island.
    readonly property int islandPad: Math.round(10 * Math.max(0.75, root.unit))

    // The rectangle the bar itself occupies, in this item's coordinates.
    readonly property rect body: Qt.rect(
        root.horizontal ? root.inset : (root.position === "left" ? root.gap : 0),
        root.horizontal ? (root.position === "top" ? root.gap : 0) : root.inset,
        root.horizontal ? root.width - 2 * root.inset : root.thickness,
        root.horizontal ? root.thickness : root.height - 2 * root.inset)

    readonly property real radius: root.style === "full" ? 0 : Math.min(Theme.radius, root.thickness / 2)
    readonly property real islandRadius: Math.min(Theme.radiusMedium, root.thickness / 2)

    // ---- what is drawn -----------------------------------------------------

    readonly property Region shape: Region {
        item: root.style === "islands" ? null : bodyRect
        radius: root.radius
        regions: root.style === "islands" ? [root._leftIsland, root._middleIsland, root._rightIsland] : []
    }
    readonly property Region _leftIsland: Region { item: leftIsland; radius: root.islandRadius }
    readonly property Region _middleIsland: Region { item: middleIsland; radius: root.islandRadius }
    readonly property Region _rightIsland: Region { item: rightIsland; radius: root.islandRadius }

    // ---- the bar -----------------------------------------------------------

    RectangularShadow {
        visible: root.style === "floating"
        anchors.fill: bodyRect
        radius: bodyRect.radius
        blur: 28
        offset.y: root.position === "top" ? 4 : 8
        color: Theme.shadow
    }

    Rectangle {
        id: bodyRect
        visible: root.style !== "islands"
        x: root.body.x
        y: root.body.y
        width: root.body.width
        height: root.body.height
        radius: root.radius
        color: Theme.bar
        border.width: root.style === "floating" ? 1 : 0
        border.color: Theme.out
        Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
    }

    // A full strip is bounded by a hairline on the side facing the screen,
    // not boxed in.
    Rectangle {
        visible: root.style === "full"
        color: Theme.out
        x: root.horizontal ? 0 : (root.position === "left" ? root.width - 1 : 0)
        y: root.horizontal ? (root.position === "top" ? root.height - 1 : 0) : 0
        width: root.horizontal ? root.width : 1
        height: root.horizontal ? 1 : root.height
    }

    // ---- islands -----------------------------------------------------------

    component Island: Item {
        id: island

        required property Item zone

        readonly property bool shown: root.style === "islands" && (island.zone.implicitWidth > 0 && island.zone.implicitHeight > 0)

        visible: island.shown
        x: root.horizontal ? island.zone.x - root.islandPad : root.body.x
        y: root.horizontal ? root.body.y : island.zone.y - root.islandPad
        width: !island.shown ? 0 : root.horizontal ? island.zone.width + 2 * root.islandPad : root.body.width
        height: !island.shown ? 0 : root.horizontal ? root.body.height : island.zone.height + 2 * root.islandPad

        RectangularShadow {
            anchors.fill: parent
            radius: root.islandRadius
            blur: 24
            offset.y: root.position === "top" ? 3 : 6
            color: Theme.shadow
        }

        Rectangle {
            anchors.fill: parent
            radius: root.islandRadius
            color: Theme.bar
            border.width: 1
            border.color: Theme.out
            Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
        }
    }

    Island { id: leftIsland; zone: leftZone }
    Island { id: middleIsland; zone: middleZone }
    Island { id: rightIsland; zone: rightZone }

    // ---- the zones ---------------------------------------------------------
    //
    // Left and right hug the ends of the bar; middle is centred on the bar
    // itself, not on the space left over between the other two, so a long
    // window title on the left cannot shove the clock off-centre. Positioned
    // with x/y rather than anchors, for the reason given in Panel.qml.

    readonly property int lead: root.pad + (root.style === "islands" ? root.islandPad : 0)

    // How much of the bar each zone may take before it runs into another --
    // what a widget that can give way, the task list, has to fit in. The
    // middle has everything between the two ends; an end has what the middle
    // and the other end leave. Nothing here depends on a zone's own length,
    // so a widget shrinking into its room does not change the room.
    readonly property real bodyLength: root.horizontal ? root.body.width : root.body.height
    readonly property real bodyStart: root.horizontal ? root.body.x : root.body.y
    readonly property int zoneGap: Math.round(16 * Math.max(0.7, root.unit)) + (root.style === "islands" ? 2 * root.islandPad : 0)
    function lengthOf(zone) { return root.horizontal ? zone.width : zone.height; }
    function startOf(zone) { return root.horizontal ? zone.x : zone.y; }

    // Never negative. A zone reads -1 as "no limit", so arithmetic that ran
    // past zero handed the most crowded panel of all the fewest constraints --
    // which is how a taskbar with too many windows ended up drawn over the
    // clock rather than cut short.
    readonly property real middleRoom: Math.max(0, root.bodyLength - root.lengthOf(leftZone) - root.lengthOf(rightZone)
        - 2 * (root.lead + root.zoneGap))
    function endRoom(other) {
        const middle = root.lengthOf(middleZone);
        return Math.max(0, root.bodyLength - root.lengthOf(other) - middle - 2 * root.lead
                           - (middle > 0 ? 2 : 1) * root.zoneGap);
    }

    // The middle is centred on the bar itself while it fits there, so a long
    // title at one end cannot shove a clock in the middle off-centre. When it
    // does not fit there, it moves over just far enough to clear the ends.
    readonly property real middleStart: {
        const len = root.lengthOf(middleZone);
        const centred = root.bodyStart + (root.bodyLength - len) / 2;
        const lo = root.startOf(leftZone) + root.lengthOf(leftZone) + root.zoneGap;
        const hi = root.startOf(rightZone) - root.zoneGap - len;
        return hi < lo ? lo : Math.max(lo, Math.min(centred, hi));
    }

    ZoneRow {
        id: leftZone
        zone: "left"
        room: root.endRoom(rightZone)
        bar: root.bar
        screenName: root.bar.screenName
        horizontal: root.horizontal
        x: root.horizontal ? root.body.x + root.lead : root.body.x + (root.body.width - width) / 2
        y: root.horizontal ? root.body.y + (root.body.height - height) / 2 : root.body.y + root.lead
    }

    ZoneRow {
        id: middleZone
        zone: "middle"
        room: root.middleRoom
        bar: root.bar
        screenName: root.bar.screenName
        horizontal: root.horizontal
        x: root.horizontal ? root.middleStart : root.body.x + (root.body.width - width) / 2
        y: root.horizontal ? root.body.y + (root.body.height - height) / 2 : root.middleStart
    }

    ZoneRow {
        id: rightZone
        zone: "right"
        room: root.endRoom(leftZone)
        bar: root.bar
        screenName: root.bar.screenName
        horizontal: root.horizontal
        x: root.horizontal ? root.body.x + root.body.width - root.lead - width : root.body.x + (root.body.width - width) / 2
        y: root.horizontal ? root.body.y + (root.body.height - height) / 2 : root.body.y + root.body.height - root.lead - height
    }
}
