/*
    SPDX-License-Identifier: GPL-3.0-or-later

    A countdown, as a ring that empties and a number in the middle of it.

    Drawn by the lockout toast and the low-battery countdown, which the design
    draws the same way at two sizes: a conic sweep over a faint track, and the
    time left in the hole. A Shape rather than a Canvas, so it is redrawn by
    the scene graph rather than repainted by script once a second.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: ring

    // How much is left, 0 to 1.
    property real fraction: 1
    property string label: ""

    property color color: "#e0786a"
    property color track: Qt.rgba(1, 1, 1, 0.12)
    property color ink: "#f4efe8"
    property real thickness: Math.max(2, Math.round(width * 0.1))
    property int labelSize: Math.round(width * 0.3)
    property int labelWeight: Font.Medium
    property string family: "JetBrains Mono"

    readonly property real radius: (Math.min(ring.width, ring.height) - ring.thickness) / 2

    Shape {
        anchors.fill: parent

        ShapePath {
            strokeColor: ring.track
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: ring.color
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, ring.fraction))

                Behavior on sweepAngle { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: ring.label
        textFormat: Text.PlainText
        color: ring.ink
        font.family: ring.family
        font.pixelSize: ring.labelSize
        font.weight: ring.labelWeight
    }
}
