// How a check or a step went, as a filled circle with a mark in it: a tick,
// a cross, an "i", or a turning ring while it runs.
//
// Drawn as a circle and an outline glyph, not as Material's filled symbols:
// those overlap their own contours, and in a real window (not offscreen) the
// overlap drew as a second shape over the tick. The Stepper's done steps are
// made the same way, and are clean.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Item {
    id: root

    property string mark: "wait"    // wait | running | ok | warn | fail
    property real size: 22

    implicitWidth: root.size
    implicitHeight: root.size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: root.mark === "ok" || root.mark === "warn" || root.mark === "fail"
        color: ({ ok: Theme.positive, warn: Theme.warning, fail: Theme.error })[root.mark] ?? "transparent"

        Glyph {
            anchors.centerIn: parent
            size: root.size * 0.72
            color: "white"
            name: ({ ok: "check", warn: "priority_high", fail: "close" })[root.mark] ?? ""
            fallback: ({ ok: "dialog-ok", warn: "dialog-information", fail: "dialog-error" })[root.mark] ?? ""
        }
    }

    // Waiting, or running: a ring, turning while it runs.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: width / 2
        visible: root.mark === "wait" || root.mark === "running"
        color: "transparent"
        border.width: 2
        border.color: root.mark === "running" ? Theme.outlineVariant : Theme.mut

        Rectangle {
            visible: root.mark === "running"
            width: parent.width / 2
            height: 2
            x: parent.width / 2
            y: parent.height / 2 - 1
            color: Theme.acc
            transformOrigin: Item.Left
            RotationAnimation on rotation {
                running: root.mark === "running"
                from: 0; to: 360; duration: 900
                loops: Animation.Infinite
            }
        }
    }
}
