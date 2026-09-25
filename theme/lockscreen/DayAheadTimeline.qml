/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The ruler in the day-ahead style's middle card: the palette's day, dawn
    to dawn, top to bottom, with the four phases as tinted bands, the hours
    down the side, the stretch this screen has been locked for on the rail,
    and a line across at now.

    It is told where now is rather than working it out, so it moves when the
    card says it has, which is once a minute.
*/
pragma ComponentBehavior: Bound

import QtQuick

// The ruler. An hour is `step` tall; the palette's day starts at 05:00 at
// the top and ends there at the bottom.
Item {
    id: ruler

    required property DayAheadPalette colours
    property real unit: 1
    required property color accent

    // The clock, for the time drawn at the "now" line.
    required property date now

    // Where now falls on the palette's day, 5 to 29, the band it falls in,
    // and how many minutes that band has left.
    required property real cycleNow
    required property int bandIndex
    required property int minsLeft

    // The clock's time, and the moment it locked, to the minute.
    required property double minuteNow
    required property double lockedMinute

    function px(v: real): int {
        return Math.round(v * ruler.unit);
    }

    readonly property real step: ruler.height / 24
    readonly property int timeX: ruler.px(14)
    readonly property int railX: ruler.px(14 + 52 + 16)
    readonly property int railW: ruler.px(10)
    readonly property int textX: ruler.railX + ruler.railW + ruler.px(16)
    readonly property real nowY: (ruler.cycleNow - 5) * ruler.step

    function yOf(h: real): real {
        return (h - 5) * ruler.step;
    }

    // The bands, as the design draws its event rows: the current one on a
    // chip, the ones gone by faded.
    Repeater {
        model: ruler.colours.bands

        Item {
            id: bandRow

            required property var modelData
            required property int index

            readonly property bool current: bandRow.index === ruler.bandIndex
            readonly property bool past: ruler.cycleNow >= bandRow.modelData.to
            readonly property bool next: bandRow.index === (ruler.bandIndex + 1) % ruler.colours.bands.length
            readonly property var phaseColours: ruler.colours.palettes[bandRow.modelData.key]

            y: ruler.yOf(bandRow.modelData.from) + 1
            width: ruler.width
            height: ruler.yOf(bandRow.modelData.to) - ruler.yOf(bandRow.modelData.from) - 2

            Rectangle {
                anchors.fill: parent
                radius: ruler.px(16)
                color: bandRow.current ? ruler.colours.chipFill : "transparent"
            }

            // The rail, in the band's own colours: pale for the light phases,
            // deep for the dark ones.
            Rectangle {
                x: ruler.railX
                y: ruler.px(6)
                width: ruler.railW
                height: parent.height - ruler.px(12)
                radius: width / 2
                opacity: bandRow.past ? 0.55 : 1
                border.width: 1
                border.color: ruler.colours.line
                gradient: Gradient {
                    GradientStop { position: 0; color: bandRow.phaseColours.g0 }
                    GradientStop { position: 1; color: bandRow.phaseColours.g2 }
                }
            }

            // The label stays clear of the "now" line: under it where the band
            // has room, over it where it does not.
            Column {
                id: bandText

                readonly property real rest: ruler.px(10)
                readonly property real nowAt: ruler.nowY - bandRow.y
                readonly property bool crossed: bandRow.current
                    && bandText.nowAt > bandText.rest - ruler.px(8)
                    && bandText.nowAt < bandText.rest + bandText.height + ruler.px(8)
                readonly property real under: bandText.nowAt + ruler.px(12)

                x: ruler.textX
                y: !bandText.crossed ? bandText.rest
                    : bandText.under + bandText.height <= bandRow.height - ruler.px(4) ? bandText.under
                    : Math.max(ruler.px(2), bandText.nowAt - ruler.px(12) - bandText.height)
                width: parent.width - x - ruler.px(14)
                spacing: ruler.px(4)
                opacity: bandRow.past ? 0.55 : 1

                Row {
                    spacing: ruler.px(10)

                    SymbolText {
                        anchors.verticalCenter: parent.verticalCenter
                        symbol: bandRow.modelData.glyph
                        font.pixelSize: ruler.px(18)
                        color: ruler.colours.ink
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: bandRow.modelData.name
                        textFormat: Text.PlainText
                        font.family: "Rubik"
                        font.pixelSize: ruler.px(17)
                        font.weight: Font.Medium
                        color: ruler.colours.ink
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: bandRow.current || bandRow.next
                        width: tag.implicitWidth + ruler.px(16)
                        height: tag.implicitHeight + ruler.px(6)
                        radius: height / 2
                        color: ruler.accent

                        Text {
                            id: tag

                            anchors.centerIn: parent
                            text: bandRow.current ? "NOW" : "NEXT"
                            textFormat: Text.PlainText
                            font.family: "JetBrains Mono"
                            font.pixelSize: ruler.px(10.5)
                            font.weight: Font.Medium
                            font.letterSpacing: ruler.px(0.8)
                            color: "#ffffff"
                        }
                    }
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: ruler.colours.at(bandRow.modelData.from) + "–" + ruler.colours.at(bandRow.modelData.to) + " · "
                        + (bandRow.current ? ruler.colours.dur(ruler.minsLeft) + " left"
                                           : ruler.colours.dur((bandRow.modelData.to - bandRow.modelData.from) * 60))
                        + " · " + (bandRow.phaseColours.light ? "light" : "dark")
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: ruler.px(13.5)
                    color: ruler.colours.sub
                }
            }
        }
    }

    // The hours, down the time column. The one under the "now" mark gives
    // way to it.
    Repeater {
        model: 24

        Text {
            id: hourLabel

            required property int index
            readonly property int h: 5 + hourLabel.index
            readonly property bool edge: ruler.colours.bands.some(b => b.from === hourLabel.h)

            x: ruler.timeX
            y: ruler.yOf(hourLabel.h) - height / 2
            visible: Math.abs(ruler.yOf(hourLabel.h) - ruler.nowY) > ruler.px(20)
            text: ruler.colours.at(hourLabel.h)
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: ruler.px(hourLabel.edge ? 13 : 11)
            color: ruler.colours.sub
            opacity: hourLabel.edge ? 1 : 0.55
        }
    }

    // How long this screen has been locked, on the rail: from when it locked
    // to now, or from dawn if it has been locked since before it.
    Rectangle {
        readonly property real from: ruler.minuteNow - ruler.lockedMinute >= 24 * 3600000
            || ruler.colours.cycleOf(new Date(ruler.lockedMinute)) > ruler.cycleNow
            ? 0 : ruler.yOf(ruler.colours.cycleOf(new Date(ruler.lockedMinute)))

        x: ruler.railX
        y: Math.min(from, ruler.nowY - height)
        width: ruler.railW
        height: Math.max(ruler.railW, ruler.nowY - from)
        radius: width / 2
        color: Qt.alpha(ruler.accent, 0.7)
    }

    // Now: a line across, a dot on the rail, the time in the time column.
    Rectangle {
        x: ruler.timeX + ruler.px(52)
        y: ruler.nowY - height / 2
        width: ruler.width - x - ruler.px(6)
        height: Math.max(1, ruler.px(2))
        color: ruler.accent
    }

    Rectangle {
        x: ruler.railX + ruler.railW / 2 - width / 2
        y: ruler.nowY - height / 2
        width: ruler.px(16)
        height: width
        radius: width / 2
        color: ruler.accent
        border.width: ruler.px(3)
        border.color: ruler.colours.light ? "#ffffff" : ruler.colours.g1
    }

    Text {
        x: ruler.timeX
        y: ruler.nowY - height / 2
        text: LockText.pad(ruler.now.getHours()) + ":" + LockText.pad(ruler.now.getMinutes())
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"
        font.pixelSize: ruler.px(13)
        font.weight: Font.Medium
        color: ruler.accent
    }
}
