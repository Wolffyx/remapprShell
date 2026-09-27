/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The day-ahead style's middle card, where the design lists today's
    events: the day the palette keeps, dawn to dawn, as bands on a ruler
    (DayAheadTimeline), with the hour on it -- under a head naming the band
    and the time until the next, and over a foot saying when the colours
    turn.
*/
pragma ComponentBehavior: Bound

import QtQuick

DayAheadCard {
    id: today

    required property color accent

    // The clock's time, and the moment this screen locked.
    required property date now
    required property date lockedAt

    // The clock's time, and the moment it locked, to the minute. What the
    // ruler draws from them -- the now line, the hours it hides, where the
    // band labels sit, the stretch this screen has been locked -- moves once
    // a minute, not with every tick of the seconds beside the clock.
    readonly property double minuteNow: Math.floor(today.now.getTime() / 60000) * 60000
    readonly property double lockedMinute: Math.floor(today.lockedAt.getTime() / 60000) * 60000

    readonly property real cycleNow: today.colours.cycleOf(new Date(today.minuteNow))
    readonly property int bandIndex: today.colours.bands.findIndex(b => today.cycleNow >= b.from && today.cycleNow < b.to)
    readonly property var band: today.colours.bands[Math.max(0, today.bandIndex)]
    readonly property var nextBand: today.colours.bands[(Math.max(0, today.bandIndex) + 1) % today.colours.bands.length]
    readonly property int minsLeft: Math.max(1, Math.ceil((today.band.to - today.cycleNow) * 60))

    Item {
        anchors.fill: parent
        anchors.leftMargin: today.px(26)
        anchors.rightMargin: today.px(26)
        anchors.topMargin: today.px(28)
        anchors.bottomMargin: today.px(22)

        Item {
            id: todayHead

            x: today.px(14)
            width: parent.width - today.px(28)
            height: Math.max(todayCaption.height, todayNext.height)

            DayAheadCaption {
                id: todayCaption

                anchors.baseline: todayNext.baseline
                colours: today.colours
                unit: today.unit
                text: "TODAY · " + today.band.name.toUpperCase()
            }

            Text {
                id: todayNext

                anchors.right: parent.right
                text: today.nextBand.key + " in " + today.colours.dur(today.minsLeft)
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: today.px(14)
                font.weight: Font.Medium
                color: today.colours.ink
            }
        }

        Text {
            id: todayTitle

            x: today.px(14)
            y: todayHead.height + today.px(8)
            width: parent.width - today.px(28)
            text: ({
                "dawn": "Morning light until 09:00",
                "day": "Daylight until 17:00",
                "dusk": "Dusk until 20:00",
                "night": "Night until 05:00",
            })[today.colours.phase]
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: "Rubik"
            font.pixelSize: today.px(22)
            color: today.colours.ink
        }

        DayAheadTimeline {
            y: todayTitle.y + todayTitle.height + today.px(24)
            width: parent.width
            height: todayFoot.y - y - today.px(16)
            colours: today.colours
            unit: today.unit
            accent: today.accent
            now: today.now
            cycleNow: today.cycleNow
            bandIndex: today.bandIndex
            minsLeft: today.minsLeft
            minuteNow: today.minuteNow
            lockedMinute: today.lockedMinute
        }

        Item {
            id: todayFoot

            x: today.px(14)
            width: parent.width - today.px(28)
            height: today.px(14) + footLeft.height
            y: parent.height - height

            Rectangle {
                width: parent.width
                height: 1
                color: today.colours.line
            }

            Text {
                id: footLeft

                anchors.bottom: parent.bottom
                text: today.colours.light ? "Dark from 17:00"
                    : (today.colours.hour >= 17 ? "Tomorrow · light" : "Light") + " again at 05:00"
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: today.px(13)
                color: today.colours.sub
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: "the colours follow the clock"
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: today.px(13)
                color: today.colours.sub
            }
        }
    }
}
