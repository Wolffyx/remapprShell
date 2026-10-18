pragma ComponentBehavior: Bound

/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What the snap panel draws: a handle at the top of the screen while a
    window is dragged, which grows into the panel of layouts when the pointer
    comes near it. main.qml decides which, and which zone the pointer is
    over; this only draws them.

    Every place is worked out in layouts.js (`arrange`) and only drawn here,
    inside `cardLayer`, so the zone main.qml finds under the pointer is the zone
    on screen. This item is always the size of the open panel, and the
    surface grows inside it: KWin draws the window it sits in at one size for
    the whole drag, rather than being asked to resize it halfway through.

    Colours are the colour scheme's, through Kirigami.Theme, as the window
    switcher's are, so the panel matches the rest of the desktop without
    either knowing about the other.

    Opened by a key rather than a drag, it is numbered, as Windows numbers
    its own: a number on each layout, and once one is chosen by its number,
    a number on each of its zones.
*/
import QtQuick
import org.kde.kirigami as Kirigami
import "layouts.js" as Layouts

Item {
    id: flyout

    // { width, height, cards } from Layouts.arrange, or null before a drag.
    property var arrangement: null
    // { layout, zone } under the pointer, or null.
    property var hover: null
    // The layout the screen's tiles make now, marked under its card; -1 for none.
    property int current: -1
    property bool revealed: false
    // A number on each card -- or, once `armed` names a layout, on each of
    // its zones -- for choosing by the keyboard.
    property bool numbered: false
    property int armed: -1

    // Where the cards are drawn, for main.qml to measure the pointer from.
    readonly property alias cardLayer: cardLayer

    // Room around the surface for its shadow.
    readonly property int shadowPad: 18

    readonly property int panelWidth: flyout.arrangement ? flyout.arrangement.width : 0
    readonly property int panelHeight: flyout.arrangement ? flyout.arrangement.height : 0

    readonly property color ink: Kirigami.Theme.textColor
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color surfaceColor: Kirigami.Theme.backgroundColor

    // A zone at rest is the surface with a little ink in it, so it reads on
    // a light scheme and a dark one alike; one in the layout being pointed at
    // takes a little more, and the one under the pointer is the accent.
    function zoneFill(layout, zone) {
        if (flyout.hover && flyout.hover.layout === layout && flyout.hover.zone === zone)
            return flyout.accent;
        const share = flyout.hover && flyout.hover.layout === layout ? 0.2 : 0.1;
        return Qt.tint(flyout.surfaceColor, Qt.rgba(flyout.ink.r, flyout.ink.g, flyout.ink.b, share));
    }

    implicitWidth: flyout.panelWidth + 2 * flyout.shadowPad
    implicitHeight: flyout.panelHeight + 2 * flyout.shadowPad

    Kirigami.ShadowedRectangle {
        id: surface

        anchors.horizontalCenter: parent.horizontalCenter
        y: flyout.shadowPad
        width: flyout.revealed ? flyout.panelWidth : 112
        height: flyout.revealed ? flyout.panelHeight : 18
        // Square at the top, where it meets the screen's edge.
        radius: flyout.revealed ? 12 : 9
        corners.topLeftRadius: 0
        corners.topRightRadius: 0
        color: Qt.rgba(flyout.surfaceColor.r, flyout.surfaceColor.g, flyout.surfaceColor.b, 0.97)
        border.width: 1
        border.color: Qt.rgba(flyout.ink.r, flyout.ink.g, flyout.ink.b, 0.14)
        shadow.size: 16
        shadow.yOffset: 3
        shadow.color: Qt.rgba(0, 0, 0, 0.28)

        Behavior on width {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        // The handle's bar: where the panel will open, before it has.
        Rectangle {
            anchors.centerIn: parent
            width: 72
            height: 4
            radius: 2
            color: Qt.rgba(flyout.ink.r, flyout.ink.g, flyout.ink.b, 0.45)
            opacity: flyout.revealed ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: 90 }
            }
        }
    }

    Item {
        id: cardLayer

        x: (flyout.width - flyout.panelWidth) / 2
        y: flyout.shadowPad
        width: flyout.panelWidth
        height: flyout.panelHeight
        opacity: flyout.revealed && surface.height === flyout.panelHeight ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 90 }
        }

        Rectangle {
            readonly property var card: flyout.arrangement && flyout.current >= 0
                ? flyout.arrangement.cards[flyout.current] : null

            visible: card !== null
            x: card ? card.x + (card.width - width) / 2 : 0
            y: card ? card.y + card.height + 3 : 0
            width: 18
            height: 3
            radius: 1.5
            color: flyout.accent
        }

        Repeater {
            model: flyout.arrangement ? flyout.arrangement.cards : []

            delegate: Repeater {
                id: card

                required property var modelData
                required property int index

                model: card.modelData.zones

                delegate: Rectangle {
                    id: zone

                    required property var modelData
                    required property int index

                    readonly property bool lit: flyout.hover !== null
                        && flyout.hover.layout === card.index && flyout.hover.zone === zone.index

                    parent: cardLayer
                    x: zone.modelData.x
                    y: zone.modelData.y
                    width: zone.modelData.width
                    height: zone.modelData.height
                    radius: 5
                    color: flyout.zoneFill(card.index, zone.index)
                    border.width: 1
                    border.color: zone.lit
                        ? Qt.darker(flyout.accent, 1.25)
                        : Qt.rgba(flyout.ink.r, flyout.ink.g, flyout.ink.b, 0.22)

                    Behavior on color {
                        ColorAnimation { duration: 90 }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: flyout.numbered && flyout.armed === card.index && text !== ""
                        text: Layouts.digitLabel(zone.index)
                        color: zone.lit ? flyout.surfaceColor : flyout.ink
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }
        }

        // Each layout's number, over its card until one is chosen.
        Repeater {
            model: flyout.numbered && flyout.armed < 0 && flyout.arrangement ? flyout.arrangement.cards : []

            delegate: Rectangle {
                required property var modelData
                required property int index

                visible: Layouts.digitLabel(index) !== ""
                x: modelData.x + (modelData.width - width) / 2
                y: modelData.y + (modelData.height - height) / 2
                width: 20
                height: 20
                radius: 10
                color: flyout.surfaceColor
                border.width: 1
                border.color: Qt.rgba(flyout.ink.r, flyout.ink.g, flyout.ink.b, 0.3)

                Text {
                    anchors.centerIn: parent
                    text: Layouts.digitLabel(parent.index)
                    color: flyout.ink
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
