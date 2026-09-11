// A number with a visible range.

import QtQuick
import QtQuick.Controls
import qs.ui.primitives
import qs.domain.theme

Row {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property bool live: false
    // The number beside the track. Off where the value is shown elsewhere.
    property bool showReadout: true
    property string unit: ""
    signal moved(real value)

    spacing: 12

    Slider {
        id: slider
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - (root.showReadout ? readout.width + root.spacing : 0)

        // Explicit, and this is not cosmetic. A Controls Slider takes its
        // implicit height from its background and handle, and replacing both
        // with plain Rectangles that have no implicit size of their own
        // collapses the whole control to zero height: it drew nothing, and
        // there was nothing to drag. The setting looked broken because it was.
        height: 22
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value

        // Only on release: a settings write per pixel of drag would debounce
        // into the same result, but it would also log and re-render all the way.
        // A live slider -- a volume, which should follow the finger and costs
        // nothing to write -- reports every step instead.
        onPressedChanged: if (!pressed && !root.live) root.moved(value)
        onMoved: if (root.live) root.moved(value)

        background: Rectangle {
            implicitWidth: 120
            implicitHeight: 6
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 6
            radius: 3
            color: Theme.alpha(Theme.fg, 0.14)

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: Theme.acc
            }
        }

        handle: Rectangle {
            implicitWidth: 18
            implicitHeight: 18
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 18
            height: 18
            radius: 9
            color: Theme.acc
            border.width: slider.pressed ? 4 : 0
            border.color: Theme.alpha(Theme.accFg, 0.35)
        }
    }

    PanelText {
        id: readout
        visible: root.showReadout
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        text: Math.round(slider.value) + root.unit
        color: Theme.mut
        font.family: Theme.monoFamily
        font.pixelSize: 12
    }
}
