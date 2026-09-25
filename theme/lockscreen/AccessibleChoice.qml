/*
    SPDX-License-Identifier: GPL-3.0-or-later

    One of the accessible style's choices: a segment of the text size and
    contrast choices, or one of the switches -- a bordered box, filled with
    the accent while it is on, that Tab reaches and Space or Enter presses.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: choice

    // The frame, to give the keyboard back to the password after a click.
    required property var ui
    required property AccessibleLook look

    property string label: ""
    property string glyph: ""
    property bool on: false
    property bool isSwitch: false
    property string description: ""
    signal activated

    function activate(): void {
        choice.activated();
    }

    width: choiceRow.implicitWidth + 2 * Math.round(18 * choice.look.s)
    height: Math.round(52 * choice.look.s)
    radius: Math.round(12 * choice.look.s)
    color: choice.on ? choice.look.acc : (choiceHover.hovered ? choice.look.hot : "transparent")
    border.width: choice.look.line
    border.color: choice.look.bd
    activeFocusOnTab: true

    Row {
        id: choiceRow

        anchors.centerIn: parent
        spacing: Math.round(10 * choice.look.s)

        SymbolText {
            anchors.verticalCenter: parent.verticalCenter
            visible: choice.glyph !== ""
            symbol: choice.glyph
            font.pixelSize: Math.round(24 * choice.look.s)
            color: choice.on ? choice.look.accentFg : choice.look.fg
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: choice.isSwitch ? `${choice.label}: ${choice.on ? "On" : "Off"}` : choice.label
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: Math.round(18 * choice.look.s)
            font.weight: Font.Medium
            color: choice.on ? choice.look.accentFg : choice.look.fg
        }
    }

    AccessibleRing { target: choice; look: choice.look }

    HoverHandler { id: choiceHover; cursorShape: Qt.PointingHandCursor }
    // A click leaves the keyboard in the password field; a key press on
    // a focused switch leaves it on the switch, where Tab put it.
    TapHandler {
        onTapped: {
            choice.activate();
            choice.ui.focusPassword();
        }
    }
    Keys.onSpacePressed: choice.activate()
    Keys.onReturnPressed: choice.activate()
    Keys.onEnterPressed: choice.activate()

    Accessible.role: choice.isSwitch ? Accessible.CheckBox : Accessible.RadioButton
    Accessible.name: choice.label
    Accessible.description: choice.description
    Accessible.checkable: true
    Accessible.checked: choice.on
    Accessible.focusable: true
    Accessible.onPressAction: choice.activate()
    Accessible.onToggleAction: choice.activate()
}
