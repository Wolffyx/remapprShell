/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The day-ahead design's small capitals over a card or a figure: "TODAY",
    "LOCKED AT", "SESSION".
*/
pragma ComponentBehavior: Bound

import QtQuick

Text {
    id: caption

    required property DayAheadPalette colours
    property real unit: 1

    textFormat: Text.PlainText
    font.family: "JetBrains Mono"
    font.pixelSize: Math.round(12 * caption.unit)
    font.letterSpacing: Math.round(1.7 * caption.unit)
    color: caption.colours.sub
}
