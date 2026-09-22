pragma ComponentBehavior: Bound

// One zone of the panel: the enabled entries for that zone, in config order.
//
// A Repeater over the model means adding, removing or reordering a widget in
// the config file rebuilds only this zone, with no restart.

import QtQuick
import qs.features.panel.model

Item {
    id: root

    required property string zone
    required property var bar
    required property string screenName
    required property bool horizontal

    // A zone never draws past the room it was given. Widgets that can give way
    // shrink into it (the task list); the rest keep their size, and what will
    // not fit is cut at the zone's edge rather than drawn over the zone beside
    // it. Something has to give on a panel with no space left, and a clipped
    // last icon is better than two widgets on top of each other.
    readonly property bool bounded: root.room >= 0
    clip: root.bounded

    implicitWidth: root.horizontal && root.bounded
                   ? Math.min(layout.implicitWidth, root.room)
                   : layout.implicitWidth
    implicitHeight: !root.horizontal && root.bounded
                    ? Math.min(layout.implicitHeight, root.room)
                    : layout.implicitHeight

    // How long this zone may grow along the panel before it runs into the
    // next; -1 for no limit. See PanelSurface.
    property real room: -1

    // What is left of the room for one slot once every other slot has its
    // length: what a widget that can give way -- the task list -- fits into.
    // Read from the others alone, so the slot shrinking changes nothing it
    // depends on.
    function roomFor(slot) {
        if (root.room < 0)
            return -1;
        let others = 0;
        let count = 0;
        for (const c of layout.children) {
            if (c === slots || c === slot || !c.visible)
                continue;
            others += root.horizontal ? c.implicitWidth : c.implicitHeight;
            count++;
        }
        return Math.max(0, root.room - others - count * layout.spacing);
    }

    // What this zone takes whatever room it is given: every slot's fixed
    // length and the spacing between them. The other zones' rooms are worked
    // out from this rather than from this zone's drawn length, which depends
    // on its own room -- reading that went round a loop through all three.
    readonly property int shown: layout.shown
    readonly property real fixedLength: {
        let total = 0;
        let count = 0;
        for (const c of layout.children) {
            if (c === slots || !c.visible)
                continue;
            total += c.fixedLength;
            count++;
        }
        return total + Math.max(0, count - 1) * layout.spacing;
    }

    // See the Repeater below for why this is a string and not the list.
    readonly property string entriesKey: JSON.stringify(PanelModel.entriesForScreen(root.screenName, root.zone))
    property var entries: []

    onEntriesKeyChanged: root.entries = JSON.parse(root.entriesKey)
    Component.onCompleted: root.entries = JSON.parse(root.entriesKey)

    // A Grid rather than a Row/Column pair: one element that lays out either
    // way, so nothing below has to branch on orientation. `rows: 1` gives a
    // single horizontal line, `columns: 1` a single vertical one -- and the
    // other dimension must be -1, not 0. Zero is not "unset": Qt reads
    // rows * columns as the capacity, so a zone with a second widget in it
    // warned that it held more items than would fit and laid them out
    // accordingly. It only showed up once a zone had two.
    //
    // And only `columns` is set; `rows` is left for the Grid to work out. When
    // the panel changes orientation while it runs, two bound properties are
    // updated one after the other, and swapping `rows: 1, columns: N` for the
    // reverse passes through 1 x 1 whichever goes first -- a capacity of one,
    // and the same warning. With one property there is no halfway state.
    //
    // The count is of slots actually shown, not of entries. A widget with
    // nothing to show (a battery on a desktop) is hidden, and a column kept
    // for it is an empty cell with spacing on both sides: the whole zone sat
    // ten pixels off its edge. Reading each child's `visible` in the binding is
    // what makes it follow a widget appearing or disappearing. The Repeater is
    // a child of the Grid too, and is not a slot.
    Grid {
        id: layout

        readonly property int shown: Array.prototype.filter.call(layout.children,
            c => c !== slots && c.visible).length

        // Anchored to the end of the panel this zone belongs to, not centred.
        // It only matters once a zone is clipped: centred, it lost widgets
        // from both ends at once, and the clock -- the last thing anybody
        // wants cut -- went first because it sits furthest out.
        // One anchor across the panel, and a position along it: setting left,
        // right and horizontalCenter together is a warning even when only one
        // of them is ever in force.
        anchors.verticalCenter: root.horizontal ? parent.verticalCenter : undefined
        anchors.horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter

        // The far zone keeps its far end. Zero while the zone fits, since the
        // zone is then exactly as long as this.
        x: root.horizontal && root.zone === "right" ? root.width - layout.width : 0
        y: !root.horizontal && root.zone === "right" ? root.height - layout.height : 0

        columns: root.horizontal ? Math.max(1, layout.shown) : 1
        spacing: root.bar?.spacing ?? 6
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            id: slots

            // Not the function call directly. A binding to it yields a fresh
            // array on every configuration change of any kind, and a Repeater
            // handed a new array rebuilds every delegate -- so changing the
            // panel thickness, or anything else, destroyed and recreated every
            // widget on the panel. That is what "the taskbar resets when I
            // change a setting" was.
            //
            // The string only changes when the entries actually change, so the
            // model is replaced then and at no other time.
            model: root.entries

            WidgetSlot {
                id: slot
                required property var modelData
                room: root.roomFor(slot)
                entry: modelData
                bar: root.bar
                screenName: root.screenName
                widgetConfig: PanelModel.configFor(modelData)
            }
        }
    }
}
