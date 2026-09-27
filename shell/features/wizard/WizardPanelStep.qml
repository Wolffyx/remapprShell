// The first-run wizard, step 2 of 7: where the panel goes, and how thick it
// is.
//
// A step is only what it draws. The window holds the answers, hands them in,
// and takes a new one from each signal -- nothing is written here, or until
// Finish.

import QtQuick
import qs.ui.controls

Column {
    id: root

    property string position: "bottom"
    property int thickness: 52

    signal positionPicked(string value)
    signal thicknessMoved(int value)

    spacing: 6

    SettingRow {
        width: parent.width
        label: "Position"
        Select {
            values: ["bottom", "top", "left", "right"]
            currentIndex: Math.max(0, ["bottom", "top", "left", "right"].indexOf(root.position))
            onPicked: value => root.positionPicked(value)
        }
    }

    SettingRow {
        width: parent.width
        label: "Thickness"
        NumberSlider {
            width: parent.width
            from: 20
            to: 96
            stepSize: 2
            value: root.thickness
            onMoved: value => root.thicknessMoved(Math.round(value))
        }
    }
}
