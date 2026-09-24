/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The day-ahead style's palette: the design's four phases, colour for
    colour, the one the hour is in, and its colours easing into the next
    phase's rather than snapping at 17:00.

    Also the palette's own day -- dawn to dawn, as the ruler draws it -- and
    the ways a time on it is said. Every part of the style is drawn from this
    one object, so a part is handed it rather than eight colours that change
    together.
*/
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: palette

    // The hour, from the clock the style already has ticking.
    property int hour: 0

    // The crossfade between phases goes with the rest of the motion.
    property bool reduceMotion: false

    // The design's PHASES, colour for colour. `stop` is where its middle
    // colour sits along the 160-degree gradient.
    readonly property var palettes: ({
        "dawn": {
            g0: "#f3dac6", g1: "#e8c9cf", g2: "#c8c6e4", stop: 0.5,
            ink: "#241f1b", sub: "#4a433c",
            card: Qt.rgba(1, 1, 1, 0.5),
            line: Qt.rgba(36 / 255, 31 / 255, 27 / 255, 0.14),
            chip: Qt.rgba(36 / 255, 31 / 255, 27 / 255, 0.08),
            light: true,
        },
        "day": {
            g0: "#f1f2f5", g1: "#dde5f1", g2: "#f1e7da", stop: 0.5,
            ink: "#1d1b18", sub: "#4f4a43",
            card: Qt.rgba(1, 1, 1, 0.66),
            line: Qt.rgba(29 / 255, 27 / 255, 24 / 255, 0.12),
            chip: Qt.rgba(29 / 255, 27 / 255, 24 / 255, 0.07),
            light: true,
        },
        "dusk": {
            g0: "#35294a", g1: "#6e4658", g2: "#a86a56", stop: 0.52,
            ink: "#ffffff", sub: Qt.rgba(1, 1, 1, 0.86),
            card: Qt.rgba(20 / 255, 12 / 255, 20 / 255, 0.36),
            line: Qt.rgba(1, 1, 1, 0.18),
            chip: Qt.rgba(1, 1, 1, 0.14),
            light: false,
        },
        "night": {
            g0: "#0e1122", g1: "#191d38", g2: "#262136", stop: 0.55,
            ink: "#eef0fa", sub: Qt.rgba(238 / 255, 240 / 255, 250 / 255, 0.76),
            card: Qt.rgba(1, 1, 1, 0.07),
            line: Qt.rgba(1, 1, 1, 0.12),
            chip: Qt.rgba(1, 1, 1, 0.1),
            light: false,
        },
    })

    // The palette's own day, dawn to dawn, in hours: night runs past
    // midnight, to 29.
    readonly property var bands: [
        { key: "dawn", name: "Dawn", glyph: "wb_twilight", from: 5, to: 9 },
        { key: "day", name: "Day", glyph: "light_mode", from: 9, to: 17 },
        { key: "dusk", name: "Dusk", glyph: "routine", from: 17, to: 20 },
        { key: "night", name: "Night", glyph: "bedtime", from: 20, to: 29 },
    ]

    // The design's phaseOf, read from the clock that already ticks.
    readonly property string phase: palette.hour >= 5 && palette.hour < 9 ? "dawn"
        : palette.hour >= 9 && palette.hour < 17 ? "day"
        : palette.hour >= 17 && palette.hour < 20 ? "dusk" : "night"
    readonly property var tone: palette.palettes[palette.phase]
    readonly property bool light: palette.tone.light

    // Colours, each easing to the next phase's rather than snapping at 17:00.
    property color g0: palette.tone.g0
    property color g1: palette.tone.g1
    property color g2: palette.tone.g2
    property color ink: palette.tone.ink
    property color sub: palette.tone.sub
    property color cardFill: palette.tone.card
    property color line: palette.tone.line
    property color chipFill: palette.tone.chip

    readonly property int fade: palette.reduceMotion ? 0 : 1600
    Behavior on g0 { ColorAnimation { duration: palette.fade } }
    Behavior on g1 { ColorAnimation { duration: palette.fade } }
    Behavior on g2 { ColorAnimation { duration: palette.fade } }
    Behavior on ink { ColorAnimation { duration: palette.fade } }
    Behavior on sub { ColorAnimation { duration: palette.fade } }
    Behavior on cardFill { ColorAnimation { duration: palette.fade } }
    Behavior on line { ColorAnimation { duration: palette.fade } }
    Behavior on chipFill { ColorAnimation { duration: palette.fade } }

    // Caps Lock and a layout not the person's first, readable on either.
    readonly property color warn: palette.light ? "#8a5a20" : "#e0c98a"
    readonly property color bad: "#e0786a"

    // --- time -------------------------------------------------------------

    // A time of the palette's day ("05:00", "20:00"), 24 hours as drawn.
    function at(h: real): string {
        return LockText.pad(Math.floor(h) % 24) + ":00";
    }

    // The design's dur(), which counts in minutes: "40 min", "2 h",
    // "2 h 28 min".
    function dur(mins: int): string {
        return LockText.duration(mins * 60000, true);
    }

    // Where a moment falls on the palette's day, 5 to 29.
    function cycleOf(d: date): real {
        return ((d.getHours() + d.getMinutes() / 60 + d.getSeconds() / 3600) - 5 + 24) % 24 + 5;
    }
}
