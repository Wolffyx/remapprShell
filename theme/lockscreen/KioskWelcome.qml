/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The kiosk style's welcome: the headline, what a guest can do, the one
    big guest action, and the house rule -- or, where the machine cannot
    switch users, a headline saying the computer is locked and no button.
*/
pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: welcome

    // The frame, for the session the guest action switches away from.
    required property var ui

    // The frame's scale, and the one "Larger text" enlarges reading type by.
    property real unit: 1
    property real textUnit: 1
    property bool larger: false

    // Whether the greeter can open the login screen for somebody else.
    property bool canGuest: false

    // The page's colours, which the style sets.
    required property color ink
    required property color sub
    required property color card
    required property color hair
    required property color accent

    spacing: 0

    Text {
        width: parent.width
        text: welcome.canGuest ? "Welcome.\nUse this computer\nas a guest."
                               : "Welcome.\nThis computer is\nlocked for now."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        lineHeightMode: Text.FixedHeight
        lineHeight: Math.round(87 * welcome.unit)
        font.family: "Rubik"
        font.pixelSize: Math.round(84 * welcome.unit)
        font.weight: Font.Light
        font.letterSpacing: -Math.round(2.5 * welcome.unit)
        color: welcome.ink
    }

    Item { width: 1; height: Math.round(24 * welcome.unit); visible: lede.visible }

    Text {
        id: lede

        width: Math.round(760 * welcome.unit)
        visible: welcome.canGuest
        text: "Start your own session from the login screen. Whoever was here before stays locked and private."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        lineHeightMode: Text.FixedHeight
        lineHeight: Math.round(31 * welcome.textUnit)
        font.family: "Rubik"
        font.pixelSize: Math.round(21 * welcome.textUnit)
        color: welcome.sub
    }

    Item { width: 1; height: Math.round(44 * welcome.unit); visible: guest.visible }

    // The one big action.
    Rectangle {
        id: guest

        visible: welcome.canGuest
        width: Math.round(640 * welcome.unit) + (welcome.larger ? Math.round(120 * welcome.unit) : 0)
        height: Math.max(Math.round(104 * welcome.unit), guestText.implicitHeight + Math.round(40 * welcome.unit))
        radius: Math.round(26 * welcome.unit)
        color: guestHover.hovered ? Qt.lighter(welcome.accent, 1.1) : welcome.accent

        SymbolText {
            id: guestGlyph

            x: Math.round(36 * welcome.unit)
            anchors.verticalCenter: parent.verticalCenter
            symbol: "play_arrow"
            font.pixelSize: Math.round(36 * welcome.textUnit)
            color: "#ffffff"
        }

        Column {
            id: guestText

            anchors.left: guestGlyph.right
            anchors.leftMargin: Math.round(16 * welcome.unit)
            anchors.right: parent.right
            anchors.rightMargin: Math.round(22 * welcome.unit)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(4 * welcome.unit)

            Text {
                width: parent.width
                text: "Start a guest session"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: "Rubik"
                font.pixelSize: Math.round(30 * welcome.textUnit)
                font.weight: Font.Medium
                color: "#ffffff"
            }

            Text {
                width: parent.width
                text: "Opens the login screen for a guest to sign in · this session stays locked"
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                font.family: "Rubik"
                font.pixelSize: Math.round(15 * welcome.textUnit)
                color: Qt.rgba(1, 1, 1, 0.84)
            }
        }

        HoverHandler { id: guestHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: welcome.ui.session.switchUser() }
        Accessible.role: Accessible.Button
        Accessible.name: "Start a guest session"
        Accessible.description: "Opens the login screen for a guest to sign in. This session stays locked."
    }

    Item { width: 1; height: Math.round(48 * welcome.unit); visible: note.visible }

    // The house rule: one, the place's own, or none at all.
    Rectangle {
        id: note

        visible: Options.kioskNote !== ""
        width: guest.visible ? guest.width : Math.round(640 * welcome.unit)
        height: noteRow.height + Math.round(44 * welcome.unit)
        radius: Math.round(20 * welcome.unit)
        color: welcome.card
        border.width: 1
        border.color: welcome.hair

        Row {
            id: noteRow

            x: Math.round(22 * welcome.unit)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 2 * x
            spacing: Math.round(16 * welcome.unit)

            SymbolText {
                id: noteGlyph

                anchors.verticalCenter: parent.verticalCenter
                symbol: "info"
                font.pixelSize: Math.round(26 * welcome.textUnit)
                color: welcome.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: noteRow.width - noteGlyph.width - noteRow.spacing
                text: Options.kioskNote
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                font.family: "Rubik"
                font.pixelSize: Math.round(17 * welcome.textUnit)
                color: welcome.ink
            }
        }
    }
}
