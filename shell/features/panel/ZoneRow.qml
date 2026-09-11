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

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

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

        anchors.centerIn: parent
        columns: root.horizontal ? Math.max(1, layout.shown) : 1
        spacing: 10
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
                required property var modelData
                entry: modelData
                bar: root.bar
                screenName: root.screenName
                widgetConfig: PanelModel.configFor(modelData)
            }
        }
    }
}
