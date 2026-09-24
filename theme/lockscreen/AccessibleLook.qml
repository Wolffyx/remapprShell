/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What the accessible style's choices make of the page: the scale its type
    is drawn at, the design's two palettes, and the widths of its borders and
    focus ring, which grow with the type. One object, handed to every part of
    the style, so that choosing 140% or standard contrast changes every part
    at once.
*/
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: look

    // The scale everything but the page's own margins is drawn at: the
    // frame's, times the text size chosen.
    property real s: 1

    // "high" or "standard", as chosen.
    property string contrast: "high"

    // The accent setting, which standard contrast lightens.
    property color accent: "#ffffff"

    // The design's two palettes.
    readonly property bool high: look.contrast === "high"
    readonly property color bg: look.high ? "#000000" : "#1c1a17"
    readonly property color fg: look.high ? "#ffffff" : "#f4efe8"
    readonly property color sub: look.high ? "#e6e6e6" : "#cfc7bd"
    readonly property color acc: look.high ? "#ffd84a" : Qt.tint(look.accent, Qt.rgba(1, 1, 1, 0.5))
    readonly property color bd: look.high ? "#ffffff" : Qt.rgba(1, 1, 1, 0.34)
    readonly property color bdSoft: look.high ? "#8a8a8a" : Qt.rgba(1, 1, 1, 0.14)
    readonly property color card: look.high ? "#121212" : "#27241f"
    readonly property color accentFg: look.high ? "#000000" : "#14161f"
    readonly property color err: look.high ? "#ff7a6b" : "#e0786a"
    readonly property color warn: look.high ? "#ffd84a" : "#e0c98a"
    readonly property color hot: look.high ? "#262626" : "#332f29"

    // The borders the design draws at 2 and 3 px, and the focus ring.
    readonly property int line: Math.max(2, Math.round(2 * look.s))
    readonly property int thick: Math.max(3, Math.round(3 * look.s))
    readonly property int ringGap: Math.max(3, Math.round(4 * look.s))
}
