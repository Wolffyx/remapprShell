/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The accessible style's caption strip, along the foot in the accent: the
    last thing this screen announced, and a label saying that is what it is
    -- this screen's own words, not a screen reader's.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: strip

    required property AccessibleLook look

    // What was last said, and the page's side margin, which the strip's
    // glyph and label line up with.
    property string caption: ""
    property int margin: 0

    height: Math.round(76 * strip.look.s)
    color: strip.look.acc

    SymbolText {
        id: stripGlyph

        x: strip.margin
        anchors.verticalCenter: parent.verticalCenter
        symbol: "closed_caption"
        font.pixelSize: Math.round(28 * strip.look.s)
        color: strip.look.accentFg
    }

    Text {
        anchors.left: stripGlyph.right
        anchors.leftMargin: Math.round(16 * strip.look.s)
        anchors.right: stripLabel.left
        anchors.rightMargin: Math.round(24 * strip.look.s)
        anchors.verticalCenter: parent.verticalCenter
        text: strip.caption
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: "Rubik"
        font.pixelSize: Math.round(21 * strip.look.s)
        font.weight: Font.Medium
        color: strip.look.accentFg
        // Announced from `say`, not read again as a label.
        Accessible.ignored: true
    }

    Text {
        id: stripLabel

        anchors.right: parent.right
        anchors.rightMargin: strip.margin
        anchors.verticalCenter: parent.verticalCenter
        text: "Captions · what this screen announces"
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"
        font.pixelSize: Math.round(16 * strip.look.s)
        color: strip.look.accentFg
        Accessible.ignored: true
    }
}
