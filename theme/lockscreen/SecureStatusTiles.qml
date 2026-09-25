/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The foot of the secure style's rail, where the design has VPN and Wi-Fi:
    the two things about this machine the greeter can read, the keyboard
    layout and the battery, each a tile when there is one to show.
*/
pragma ComponentBehavior: Bound

import QtQuick

// Shown from what the tiles would say rather than from the tiles' own
// `visible`, which reads false for as long as this row is hidden -- so a
// row that asked its tiles stayed hidden for good once it had been, and the
// layouts arrive after the lock screen is up. On a machine with no battery
// the layout was never drawn.
Row {
    id: machine

    // The frame, for the battery and whether the prompt is up.
    required property var ui
    required property SecurePalette colours
    property real unit: 1

    readonly property LockPower battery: machine.ui.battery

    readonly property bool hasLayout: LockKeys.layoutName !== ""
    readonly property bool hasBattery: machine.battery.present
    readonly property int tiles: (machine.hasLayout ? 1 : 0) + (machine.hasBattery ? 1 : 0)
    readonly property real tileWidth: (width - (tiles - 1) * spacing) / Math.max(1, tiles)

    function px(v: real): int {
        return Math.round(v * machine.unit);
    }

    component Tile: Rectangle {
        id: tile

        property string glyph: ""
        property string label: ""
        property string detail: ""
        property color tint: machine.colours.ink

        height: tileBody.implicitHeight + machine.px(28)
        radius: machine.px(14)
        color: "#181b1f"

        Column {
            id: tileBody

            x: machine.px(16)
            y: machine.px(14)
            width: parent.width - 2 * x
            spacing: machine.px(6)

            Row {
                spacing: machine.px(8)

                SymbolText {
                    anchors.verticalCenter: parent.verticalCenter
                    symbol: tile.glyph
                    font.pixelSize: machine.px(18)
                    color: tile.tint
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.label
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: machine.px(14)
                    font.weight: Font.Medium
                    color: tile.tint
                }
            }

            Text {
                width: parent.width
                text: tile.detail
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: "JetBrains Mono"
                font.pixelSize: machine.px(12.5)
                color: machine.colours.sub
            }
        }
    }

    spacing: machine.px(12)
    visible: machine.tiles > 0

    Tile {
        id: layoutTile

        visible: machine.hasLayout
        width: machine.tileWidth
        glyph: "keyboard"
        label: LockKeys.layouts.length > 1 ? "Layout · tap to switch" : "Keyboard layout"
        detail: LockKeys.layoutName
        tint: LockKeys.otherLayout ? machine.colours.warn : machine.colours.ink

        HoverHandler {
            enabled: LockKeys.layouts.length > 1
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            enabled: LockKeys.layouts.length > 1 && machine.ui.unlock.shown
            onTapped: {
                LockKeys.nextLayout();
                machine.ui.focusPassword();
            }
        }
        Accessible.role: Accessible.Button
        Accessible.name: "Keyboard layout: " + LockKeys.layoutName
    }

    Tile {
        id: batteryTile

        visible: machine.hasBattery
        width: machine.tileWidth
        glyph: machine.battery.glyph
        label: `Battery · ${machine.battery.percent}%`
        tint: machine.battery.plugged ? machine.colours.good : machine.colours.ink
        detail: machine.battery.plugged ? "plugged in"
            : machine.battery.remainingMsec > 0 ? `on battery · ${LockText.duration(machine.battery.remainingMsec, true)} left`
            : "on battery"
    }
}
