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
    signal moved(real value)

    spacing: 8

    Slider {
        id: slider
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - readout.width - root.spacing

        // Explicit, and this is not cosmetic. A Controls Slider takes its
        // implicit height from its background and handle, and replacing both
        // with plain Rectangles that have no implicit size of their own
        // collapses the whole control to zero height: it drew nothing, and
        // there was nothing to drag. The setting looked broken because it was.
        height: 20
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
            implicitHeight: 4
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: PlasmaColors.alpha(PlasmaColors.foreground, 0.2)

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: PlasmaColors.accent
            }
        }

        handle: Rectangle {
            implicitWidth: 14
            implicitHeight: 14
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 14
            height: 14
            radius: 7
            color: PlasmaColors.foreground
        }
    }

    PanelText {
        id: readout
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        horizontalAlignment: Text.AlignRight
        text: Math.round(slider.value)
        color: PlasmaColors.foregroundInactive
    }
}
