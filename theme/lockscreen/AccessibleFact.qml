/*
    SPDX-License-Identifier: GPL-3.0-or-later

    One of the accessible style's cards under the clock: a glyph in the
    accent and a line of large type. The keyboard layout's card can be
    pressed, to switch to the next layout; the others are read, not pressed.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: fact

    // The frame, to give the keyboard back to the password after a click.
    required property var ui
    required property AccessibleLook look

    property string glyph: ""
    property string text: ""
    property string description: ""
    // The layout card switches to the next layout.
    property bool pressable: false
    signal activated

    width: parent?.width ?? 0
    height: factText.implicitHeight + 2 * Math.round(18 * fact.look.s)
    radius: Math.round(18 * fact.look.s)
    color: fact.pressable && factHover.hovered ? fact.look.hot : fact.look.card
    border.width: fact.look.line
    border.color: fact.look.bdSoft
    activeFocusOnTab: fact.pressable

    SymbolText {
        id: factGlyph

        x: Math.round(22 * fact.look.s)
        anchors.verticalCenter: parent.verticalCenter
        symbol: fact.glyph
        font.pixelSize: Math.round(34 * fact.look.s)
        color: fact.look.acc
    }

    Text {
        id: factText

        anchors.left: factGlyph.right
        anchors.leftMargin: Math.round(18 * fact.look.s)
        anchors.right: parent.right
        anchors.rightMargin: Math.round(22 * fact.look.s)
        anchors.verticalCenter: parent.verticalCenter
        text: fact.text
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        lineHeight: 1.2
        font.family: "Rubik"
        font.pixelSize: Math.round(22 * fact.look.s)
        color: fact.look.fg
    }

    AccessibleRing { target: fact; look: fact.look }

    HoverHandler {
        id: factHover
        enabled: fact.pressable
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        enabled: fact.pressable
        onTapped: {
            fact.activated();
            fact.ui.focusPassword();
        }
    }
    Keys.onSpacePressed: if (fact.pressable) fact.activated()
    Keys.onReturnPressed: if (fact.pressable) fact.activated()
    Keys.onEnterPressed: if (fact.pressable) fact.activated()

    Accessible.role: fact.pressable ? Accessible.Button : Accessible.StaticText
    Accessible.name: fact.text
    Accessible.description: fact.description
    Accessible.onPressAction: if (fact.pressable) fact.activated()
}
