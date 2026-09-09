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

    // A Grid rather than a Row/Column pair: one element that lays out either
    // way, so nothing below has to branch on orientation. `rows: 1` gives a
    // single horizontal line, `columns: 1` a single vertical one.
    Grid {
        id: layout

        anchors.centerIn: parent
        rows: root.horizontal ? 1 : 0
        columns: root.horizontal ? 0 : 1
        spacing: 10
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            model: PanelModel.entriesFor(root.zone)

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
