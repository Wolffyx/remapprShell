/*
    SPDX-License-Identifier: GPL-3.0-or-later

    One of the secure style's method tabs, over the way in: a glyph and a
    word, lit while it is the way chosen.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: tab

    required property SecurePalette colours
    property real unit: 1

    property string glyph: ""
    property string label: ""
    property bool active: false
    signal chosen

    function px(v: real): int {
        return Math.round(v * tab.unit);
    }

    width: tabRow.implicitWidth + tab.px(36)
    height: tab.px(40)
    radius: tab.px(10)
    color: tab.active ? "#2a2f36" : (tabHover.hovered ? "#161a1e" : "transparent")

    Row {
        id: tabRow
        anchors.centerIn: parent
        spacing: tab.px(8)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: tab.glyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: tab.px(18)
            color: tab.active ? "#ffffff" : tab.colours.sub
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: tab.label
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: tab.px(14)
            font.weight: Font.Medium
            color: tab.active ? "#ffffff" : tab.colours.sub
        }
    }

    HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tab.chosen() }
    Accessible.role: Accessible.PageTab
    Accessible.name: tab.label
}
