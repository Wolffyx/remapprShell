/*
    SPDX-License-Identifier: GPL-3.0-or-later

    One of the day-ahead design's cards: rounded, in the phase's card colour,
    with a hairline round it. Every block on the board but the clock is one,
    and the parts that are cards are drawn on this.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: card

    required property DayAheadPalette colours

    // The frame's scale, as every other part takes it, and a length of the
    // design at it.
    property real unit: 1

    function px(v: real): int {
        return Math.round(v * card.unit);
    }

    radius: card.px(26)
    color: card.colours.cardFill
    border.width: 1
    border.color: card.colours.line
}
