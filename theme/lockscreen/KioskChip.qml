/*
    SPDX-License-Identifier: GPL-3.0-or-later

    One of the kiosk design's white chips: a glyph and a word. Filled with
    the ink while it is checked, and drawn plain -- no card, no border --
    where it should not look like a button yet.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: chip

    // The frame's scale, and the one "Larger text" enlarges reading type by.
    property real unit: 1
    property real textUnit: 1

    // The page's colours, which the style sets.
    required property color ink
    required property color sub
    required property color card
    required property color hair

    property string glyph: ""
    property string label: ""
    property bool checked: false
    property bool plain: false
    signal activated

    width: chipRow.implicitWidth + Math.round(32 * chip.textUnit)
    height: chipRow.implicitHeight + Math.round(22 * chip.textUnit)
    radius: Math.round(12 * chip.unit)
    color: chip.checked ? chip.ink
         : chip.plain ? (chipHover.hovered ? chip.hair : "transparent")
         : (chipHover.hovered ? "#f8f5f0" : chip.card)
    border.width: chip.plain ? 0 : 1
    border.color: chip.hair

    Row {
        id: chipRow

        anchors.centerIn: parent
        spacing: Math.round(9 * chip.textUnit)

        SymbolText {
            anchors.verticalCenter: parent.verticalCenter
            symbol: chip.glyph
            font.pixelSize: Math.round(20 * chip.textUnit)
            color: chip.checked ? chip.card : chip.plain ? chip.sub : chip.ink
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.label
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: Math.round(14 * chip.textUnit)
            color: chip.checked ? chip.card : chip.plain ? chip.sub : chip.ink
        }
    }

    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: chip.activated() }
    Accessible.role: Accessible.Button
    Accessible.name: chip.label
}
