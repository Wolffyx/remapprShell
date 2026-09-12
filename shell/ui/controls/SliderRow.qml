// A slider with its value beside its name, as the design draws it: the label
// and the number on one line, the track under them across the full width.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

Column {
    id: root

    property string label: ""
    property string unit: "px"
    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    signal moved(real value)

    width: parent ? parent.width : 0
    spacing: 6

    Item {
        width: parent.width
        height: 18

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.pixelSize: 13
        }

        PanelText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.unit.length > 0 ? `${Math.round(root.value)} ${root.unit}` : `${Math.round(root.value)}`
            font.family: Theme.monoFamily
            font.pixelSize: 12
            color: Theme.mut
        }
    }

    NumberSlider {
        width: parent.width
        showReadout: false
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value
        onMoved: value => root.moved(value)
    }
}
