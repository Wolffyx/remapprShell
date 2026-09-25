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
    readonly property real unit: root.thickness / 64

    // How far off the edge it is drawn: 1 floating, 0 against it. The panel
    // animates this between the two when a floating bar or islands fill the
    // edge for a window (Panel.defloated); anything else holding a surface
    // has no such thing, and gets its style's own.
    readonly property real floating: root.bar.floatAmount ?? (root.style === "full" ? 0 : 1)

    // The space between the bar and the screen edge, closing as it docks.
    readonly property real gap: root.bar.edgeGap * root.floating

    // Along the edge, a floating bar and islands stop short of the corners.
    readonly property real inset: 18 * root.floating
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

    readonly property real radius: Math.min(Theme.radius, root.thickness / 2) * root.floating
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
        visible: Theme.shadows && root.style === "floating"
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
            visible: Theme.shadows
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
    // what a widget that can give way, the task list, has to fit in. See
    // `rooms` below.
    readonly property real bodyLength: root.horizontal ? root.body.width : root.body.height
    readonly property real bodyStart: root.horizontal ? root.body.x : root.body.y
    readonly property int zoneGap: Math.round(16 * Math.max(0.7, root.unit)) + (root.style === "islands" ? 2 * root.islandPad : 0)
    function lengthOf(zone) { return root.horizontal ? zone.width : zone.height; }
    function startOf(zone) { return root.horizontal ? zone.x : zone.y; }

    // Never negative. A zone reads -1 as "no limit", so arithmetic that ran
    // past zero handed the most crowded panel of all the fewest constraints --
    // which is how a taskbar with too many windows ended up drawn over the
    // clock rather than cut short.
    //
    // Each room is worked out once, from the zones' fixed lengths, rather than
    // from their drawn ones. A drawn length depends on that zone's own room,
    // so the middle's room read the ends, whose rooms read the middle, and Qt
    // reported a binding loop at every panel start on a crowded bar.
    //
    // While everything fits, every zone is given its own length and all of
    // what is spare: only a widget that gives way grows into it. When it does
    // not fit, the middle gives way first, then the right end -- from its
    // inner side, so the clock at the far end is the last thing cut -- and
    // the left end last.
    readonly property var rooms: {
        const l = leftZone.fixedLength;
        const m = middleZone.fixedLength;
        const r = rightZone.fixedLength;
        const avail = Math.max(0, root.bodyLength - 2 * root.lead
                                  - (middleZone.shown > 0 ? 2 : 1) * root.zoneGap);
        const spare = avail - l - m - r;
        if (spare >= 0)
            return { left: l + spare, middle: m + spare, right: r + spare };
        const middle = Math.max(0, avail - l - r);
        const right = Math.max(0, Math.min(r, avail - l));
        return { left: Math.min(l, avail), middle: middle, right: right };
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
        room: root.rooms.left
        bar: root.bar
        screenName: root.bar.screenName
        horizontal: root.horizontal
        x: root.horizontal ? root.body.x + root.lead : root.body.x + (root.body.width - width) / 2
        y: root.horizontal ? root.body.y + (root.body.height - height) / 2 : root.body.y + root.lead
    }

    ZoneRow {
        id: middleZone
        zone: "middle"
        room: root.rooms.middle
        bar: root.bar
        screenName: root.bar.screenName
        horizontal: root.horizontal
        x: root.horizontal ? root.middleStart : root.body.x + (root.body.width - width) / 2
        y: root.horizontal ? root.body.y + (root.body.height - height) / 2 : root.middleStart
    }

    ZoneRow {
        id: rightZone
        zone: "right"
        room: root.rooms.right
        bar: root.bar
        screenName: root.bar.screenName
        horizontal: root.horizontal
        x: root.horizontal ? root.body.x + root.body.width - root.lead - width : root.body.x + (root.body.width - width) / 2
        y: root.horizontal ? root.body.y + (root.body.height - height) / 2 : root.body.y + root.body.height - root.lead - height
    }
}
