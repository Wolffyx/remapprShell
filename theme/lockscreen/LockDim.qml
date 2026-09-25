/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The screen after a while with nobody at it: the clock, and nothing else.

    Like KDE's and Caelestia's dim screen, and drawn over every style the same
    way, because what it is for does not change with the look: a lock screen
    left on a desk all afternoon should be dark and still, and should say at a
    glance that it is only waiting. `dimSeconds` sets how long; zero never
    dims. Plasma turns the screen off on its own schedule whichever it is.

    It takes nothing from the prompt: a key goes on to the password field as
    it always does, and wakes this on the way.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.mpris as Mpris

Rectangle {
    id: dim

    required property var ui
    property bool dimmed: false

    readonly property real unit: dim.ui.unit

    color: "#060605"
    opacity: dim.dimmed ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 1400; easing.type: Easing.InOutQuad } }

    // A press wakes it and goes no further; a key never reaches here at all.
    MouseArea {
        anchors.fill: parent
        enabled: dim.dimmed
        onPressed: dim.ui.unlock.poke()
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        LockClock {
            anchors.horizontalCenter: parent.horizontalCenter
            centred: true
            raised: false
            ink: "#d9d3ca"
            dateInk: "#8f877d"
            timeSize: Math.round(210 * dim.unit)
            dateSize: Math.round(22 * dim.unit)
            timeWeight: Font.ExtraLight
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: Math.round(40 * dim.unit)
            spacing: Math.round(26 * dim.unit)

            component Fact: Row {
                property string glyph
                property string text
                spacing: Math.round(8 * dim.unit)

                SymbolText {
                    anchors.verticalCenter: parent.verticalCenter
                    symbol: parent.glyph
                    font.pixelSize: Math.round(18 * dim.unit)
                    color: "#8f877d"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.text
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(14 * dim.unit)
                    color: "#8f877d"
                }
            }

            Fact {
                visible: dim.ui.battery.present
                glyph: dim.ui.battery.plugged ? "battery_charging_full" : "battery_5_bar"
                text: dim.ui.battery.percent + "%"
            }

            Repeater {
                model: LockKeys.players

                Fact {
                    required property var model
                    visible: dim.ui.setting("showMediaControls", true) && model.track.length > 0
                    glyph: model.playbackStatus === Mpris.PlaybackStatus.Playing ? "graphic_eq" : "music_note"
                    text: model.track
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(56 * dim.unit)
        text: "idle · move the mouse or press a key"
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"
        font.pixelSize: Math.round(12.5 * dim.unit)
        color: "#6a635a"
    }
}
