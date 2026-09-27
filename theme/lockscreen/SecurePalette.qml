/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The secure style's colours: the design's slate, cooler than the other
    dark styles. One object, handed to every part of the style, so each part
    names the colour it draws in rather than being given it one at a time.
*/
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    readonly property color ground: "#0e1012"
    readonly property color railGround: "#121417"
    readonly property color card: "#15181b"
    readonly property color cardLine: "#262a2f"
    readonly property color well: "#1f2327"
    readonly property color ink: "#e9e5df"
    readonly property color sub: "#a9b0b8"
    readonly property color mut: "#8b939c"
    readonly property color faint: "#7d858e"
    readonly property color good: "#7fb98a"
    readonly property color bad: "#e0786a"
    readonly property color warn: "#e0c98a"
}
