/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The day-ahead style's background: the phase's diagonal gradient, which is
    all there is behind the board -- the frame's blur and scrim are off.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// The design's `linear-gradient(160deg, ...)`, drawn as CSS draws it: a
// line through the centre at that angle, long enough that its ends touch
// the corners.
Shape {
    id: ground

    required property DayAheadPalette colours

    readonly property real dx: Math.sin(160 * Math.PI / 180)
    readonly property real dy: -Math.cos(160 * Math.PI / 180)
    readonly property real reach: (Math.abs(ground.width * ground.dx) + Math.abs(ground.height * ground.dy)) / 2

    ShapePath {
        strokeWidth: -1
        strokeColor: "transparent"
        fillGradient: LinearGradient {
            x1: ground.width / 2 - ground.dx * ground.reach
            y1: ground.height / 2 - ground.dy * ground.reach
            x2: ground.width / 2 + ground.dx * ground.reach
            y2: ground.height / 2 + ground.dy * ground.reach
            GradientStop { position: 0; color: ground.colours.g0 }
            GradientStop { position: ground.colours.tone.stop; color: ground.colours.g1 }
            GradientStop { position: 1; color: ground.colours.g2 }
        }

        startX: 0
        startY: 0
        PathLine { x: ground.width; y: 0 }
        PathLine { x: ground.width; y: ground.height }
        PathLine { x: 0; y: ground.height }
        PathLine { x: 0; y: 0 }
    }
}
