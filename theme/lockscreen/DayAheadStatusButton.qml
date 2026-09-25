/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The day-ahead design's status buttons, top right: 36 tall, a glyph or a
    word or both, and a chip's colour under the pointer.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: button

    required property DayAheadPalette colours
    property real unit: 1

    property string glyph: ""
    property string label: ""
    property string name: ""
    property color tint: button.colours.ink
    signal activated

    function px(v: real): int {
        return Math.round(v * button.unit);
    }

    width: Math.max(height, buttonRow.implicitWidth + button.px(20))
    height: button.px(36)
    radius: button.px(10)
    color: buttonHover.hovered ? button.colours.chipFill : "transparent"

    Row {
        id: buttonRow

        anchors.centerIn: parent
        spacing: button.px(8)

        SymbolText {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.glyph !== ""
            symbol: button.glyph
            font.pixelSize: button.px(20)
            color: button.tint
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.label !== ""
            text: button.label
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: button.px(13)
            color: button.tint
        }
    }

    HoverHandler { id: buttonHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: button.activated() }
    Accessible.role: Accessible.Button
    Accessible.name: button.name
}
