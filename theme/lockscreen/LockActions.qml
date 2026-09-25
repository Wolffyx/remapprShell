/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Sleep, hibernate and switch user -- the three the greeter can actually do.

    Ending the session is not among them: the screen is locked, and nobody has
    said who is asking. Each is drawn only when SessionManagement says the
    machine can do it, so a laptop without a swap file big enough to hibernate
    shows two buttons rather than a third that fails.

    The designs draw these three ways -- round on glass, square on a bar, as
    words in a row -- so the shape is the style's to choose and the actions
    are not. Nor is whether they are drawn at all: `showSessionButtons` is
    applied here, for every style.
*/
pragma ComponentBehavior: Bound

import QtQuick

Row {
    id: actions

    // SessionManagement.
    required property var session

    // "round", "square", or "text": the style's choice, and what is drawn --
    // except without the icon font, when every style's buttons are words.
    property string shape: "round"
    readonly property string drawn: Options.hasSymbols ? actions.shape : "text"

    property color ink: "#ffffff"
    property color fill: Qt.rgba(1, 1, 1, 0.14)
    property color stroke: Qt.rgba(1, 1, 1, 0.22)
    property color hot: Qt.rgba(1, 1, 1, 0.26)
    property real unit: 1
    property int size: Math.round(46 * actions.unit)

    // Whether there is anything to draw: the setting allows it and the
    // machine can do at least one of the three. For a style that puts the
    // row in a card of its own, which should go when the row has nothing.
    readonly property bool any: Options.showSessionButtons
        && (actions.session.canSuspend || actions.session.canHibernate || actions.session.canSwitchUser)

    visible: Options.showSessionButtons
    spacing: Math.round(10 * actions.unit)

    component Action: Item {
        id: action

        property string glyph: ""
        property string label: ""
        signal activated

        width: actions.drawn === "text" ? word.implicitWidth : actions.size
        height: actions.drawn === "text" ? word.implicitHeight : actions.size

        // Reachable with Tab, and pressed with Space or Enter, like any
        // button -- the accessible style's rule, and nobody else's loss.
        activeFocusOnTab: true
        Keys.onSpacePressed: action.activated()
        Keys.onReturnPressed: action.activated()
        Keys.onEnterPressed: action.activated()

        Rectangle {
            anchors.fill: parent
            anchors.margins: -Math.round(4 * actions.unit)
            visible: action.activeFocus
            radius: actions.drawn === "round" ? width / 2 : Math.round(8 * actions.unit)
            color: "transparent"
            border.width: Math.max(2, Math.round(2 * actions.unit))
            border.color: Options.accent
        }

        Rectangle {
            anchors.fill: parent
            visible: actions.drawn !== "text"
            radius: actions.drawn === "round" ? width / 2 : Math.round(width * 0.28)
            color: hover.hovered ? actions.hot : actions.fill
            border.width: 1
            border.color: actions.stroke

            SymbolText {
                anchors.centerIn: parent
                symbol: action.glyph
                font.pixelSize: Math.round(21 * actions.unit)
                color: actions.ink
            }
        }

        Text {
            id: word

            anchors.centerIn: parent
            visible: actions.drawn === "text"
            text: action.label
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: Math.round(14 * actions.unit)
            color: hover.hovered ? actions.ink : Qt.alpha(actions.ink, 0.78)
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: action.activated() }
        Accessible.role: Accessible.Button
        Accessible.name: action.label
        Accessible.onPressAction: action.activated()
    }

    Action {
        visible: actions.session.canSuspend
        glyph: "bedtime"
        label: "Sleep"
        onActivated: actions.session.suspend()
    }

    Action {
        visible: actions.session.canHibernate
        glyph: "downloading"
        label: "Hibernate"
        onActivated: actions.session.hibernate()
    }

    Action {
        visible: actions.session.canSwitchUser
        glyph: "group"
        label: "Switch user"
        onActivated: actions.session.switchUser()
    }
}
