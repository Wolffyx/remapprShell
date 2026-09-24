/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Day ahead (3a) -- agenda-first and time-of-day adaptive: the palette
    follows the clock, light at dawn and through the day, dark from dusk, and
    the middle of the screen shows the day you are unlocking into.

    The palette is the heart of it and is drawn exactly as the design has it:
    four phases by the hour (dawn 5-9, day 9-17, dusk 17-20, night otherwise),
    each its own diagonal gradient and its own ink, card, hairline and chip
    colours. It is read from the clock that is already ticking, so the screen
    goes from light to dark at 17:00 while it is locked, and crossfades rather
    than snapping. The frame's blur and scrim are off: the gradient is the
    background.

    Most of what the design fills the board with is not drawn, because the
    greeter cannot know it: the agenda (six events, "Join after unlock"),
    tomorrow's first event, the weather card and its hourly strip, reminders,
    notifications, Wi-Fi, volume, the power profile and the disk. The phase
    picker in the design's header is a review control and is not drawn either.

    The agenda's card is given to something true about the day instead: a
    ruler of the palette's own day, dawn to dawn, with the four phases as
    tinted bands, the hour, and the stretch this screen has been locked for
    marked on it. The weather card is not replaced: the left column is the
    greeting, the clock and the password, as the design's is without it. The
    right-hand stack keeps what is real -- what is playing, then a two-up card
    of when this screen locked and how many passwords it has refused, with the
    battery under them when there is one -- and the session actions, which
    the design has nowhere, sit at its foot, level with the password. The
    keyboard layout and the on-screen keyboard stay where the design has its
    status buttons, top right.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

LockStyle {
    id: day

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: password
    promptBlock: pill

    // --- the palette ------------------------------------------------------

    // The design's PHASES, colour for colour. `stop` is where its middle
    // colour sits along the 160-degree gradient.
    readonly property var palettes: ({
        "dawn": {
            g0: "#f3dac6", g1: "#e8c9cf", g2: "#c8c6e4", stop: 0.5,
            ink: "#241f1b", sub: "#4a433c",
            card: Qt.rgba(1, 1, 1, 0.5),
            line: Qt.rgba(36 / 255, 31 / 255, 27 / 255, 0.14),
            chip: Qt.rgba(36 / 255, 31 / 255, 27 / 255, 0.08),
            light: true,
        },
        "day": {
            g0: "#f1f2f5", g1: "#dde5f1", g2: "#f1e7da", stop: 0.5,
            ink: "#1d1b18", sub: "#4f4a43",
            card: Qt.rgba(1, 1, 1, 0.66),
            line: Qt.rgba(29 / 255, 27 / 255, 24 / 255, 0.12),
            chip: Qt.rgba(29 / 255, 27 / 255, 24 / 255, 0.07),
            light: true,
        },
        "dusk": {
            g0: "#35294a", g1: "#6e4658", g2: "#a86a56", stop: 0.52,
            ink: "#ffffff", sub: Qt.rgba(1, 1, 1, 0.86),
            card: Qt.rgba(20 / 255, 12 / 255, 20 / 255, 0.36),
            line: Qt.rgba(1, 1, 1, 0.18),
            chip: Qt.rgba(1, 1, 1, 0.14),
            light: false,
        },
        "night": {
            g0: "#0e1122", g1: "#191d38", g2: "#262136", stop: 0.55,
            ink: "#eef0fa", sub: Qt.rgba(238 / 255, 240 / 255, 250 / 255, 0.76),
            card: Qt.rgba(1, 1, 1, 0.07),
            line: Qt.rgba(1, 1, 1, 0.12),
            chip: Qt.rgba(1, 1, 1, 0.1),
            light: false,
        },
    })

    // The palette's own day, dawn to dawn, in hours: night runs past
    // midnight, to 29.
    readonly property var bands: [
        { key: "dawn", name: "Dawn", glyph: "wb_twilight", from: 5, to: 9 },
        { key: "day", name: "Day", glyph: "light_mode", from: 9, to: 17 },
        { key: "dusk", name: "Dusk", glyph: "routine", from: 17, to: 20 },
        { key: "night", name: "Night", glyph: "bedtime", from: 20, to: 29 },
    ]

    // The design's phaseOf, read from the clock that already ticks.
    readonly property int hour: clock.now.getHours()
    readonly property string phase: day.hour >= 5 && day.hour < 9 ? "dawn"
        : day.hour >= 9 && day.hour < 17 ? "day"
        : day.hour >= 17 && day.hour < 20 ? "dusk" : "night"
    readonly property var tone: day.palettes[day.phase]
    readonly property bool light: day.tone.light

    // Colours, each easing to the next phase's rather than snapping at 17:00.
    property color g0: day.tone.g0
    property color g1: day.tone.g1
    property color g2: day.tone.g2
    property color ink: day.tone.ink
    property color sub: day.tone.sub
    property color cardFill: day.tone.card
    property color line: day.tone.line
    property color chipFill: day.tone.chip

    readonly property int fade: day.reduceMotion ? 0 : 1600
    Behavior on g0 { ColorAnimation { duration: day.fade } }
    Behavior on g1 { ColorAnimation { duration: day.fade } }
    Behavior on g2 { ColorAnimation { duration: day.fade } }
    Behavior on ink { ColorAnimation { duration: day.fade } }
    Behavior on sub { ColorAnimation { duration: day.fade } }
    Behavior on cardFill { ColorAnimation { duration: day.fade } }
    Behavior on line { ColorAnimation { duration: day.fade } }
    Behavior on chipFill { ColorAnimation { duration: day.fade } }

    // Caps Lock and a layout not the person's first, readable on either.
    readonly property color warn: day.light ? "#8a5a20" : "#e0c98a"
    readonly property color bad: "#e0786a"

    // --- time -------------------------------------------------------------

    // A time of the palette's day ("05:00", "20:00"), 24 hours as drawn.
    function at(h: real): string {
        return LockText.pad(Math.floor(h) % 24) + ":00";
    }

    // The design's dur(), which counts in minutes: "40 min", "2 h",
    // "2 h 28 min".
    function dur(mins: int): string {
        return LockText.duration(mins * 60000, true);
    }

    // Where a moment falls on the palette's day, 5 to 29.
    function cycleOf(d: date): real {
        return ((d.getHours() + d.getMinutes() / 60 + d.getSeconds() / 3600) - 5 + 24) % 24 + 5;
    }

    readonly property real cycleNow: day.cycleOf(clock.now)
    readonly property int bandIndex: day.bands.findIndex(b => day.cycleNow >= b.from && day.cycleNow < b.to)
    readonly property var band: day.bands[Math.max(0, day.bandIndex)]
    readonly property var nextBand: day.bands[(Math.max(0, day.bandIndex) + 1) % day.bands.length]
    readonly property int minsLeft: Math.max(1, Math.ceil((day.band.to - day.cycleNow) * 60))

    readonly property string greeting: {
        const h = day.hour;
        if (h < 5 || h >= 22) return "Good night";
        if (h < 12) return "Good morning";
        if (h < 18) return "Good afternoon";
        return "Good evening";
    }

    // In whole minutes, so the line changes once a minute however often
    // `now` ticks.
    readonly property string lockedAgo: "locked " + LockText.ago(day.ui.lockedAt, clock.now, true)
    readonly property string lockedTime: day.ui.lockedAt.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)

    // --- the machine ------------------------------------------------------

    readonly property LockPower battery: day.ui.battery

    readonly property string batteryLine: {
        const left = day.dur(Math.max(1, Math.round(day.battery.remainingMsec / 60000)));
        if (day.battery.plugged) {
            if (day.battery.full)
                return "plugged in · full";
            if (day.battery.charging)
                return day.battery.remainingMsec > 0 ? "charging · full in " + left : "charging";
            return "plugged in · not charging";
        }
        return day.battery.remainingMsec > 0 ? "on battery · " + left + " left" : "on battery";
    }

    // --- pieces -----------------------------------------------------------

    component Card: Rectangle {
        radius: day.px(26)
        color: day.cardFill
        border.width: 1
        border.color: day.line
    }

    component Caption: Text {
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"
        font.pixelSize: day.px(12)
        font.letterSpacing: day.px(1.7)
        color: day.sub
    }

    // The design's big number with a small note after it: "84% · 40 min to full".
    component Figure: Row {
        id: figure

        property string value: ""
        property string note: ""
        property color tint: day.ink

        width: parent?.width ?? 0
        spacing: day.px(6)

        Text {
            id: figureValue

            text: figure.value
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: day.px(22)
            color: figure.tint
        }

        Text {
            anchors.baseline: figureValue.baseline
            width: figure.width - figureValue.width - figure.spacing
            visible: figure.note !== ""
            elide: Text.ElideRight
            text: "· " + figure.note
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: day.px(13)
            color: day.sub
        }
    }

    // The design's status buttons: 36 tall, a chip's colour under the pointer.
    component StatusButton: Rectangle {
        id: button

        property string glyph: ""
        property string label: ""
        property string name: ""
        property color tint: day.ink
        signal activated

        width: Math.max(height, buttonRow.implicitWidth + day.px(20))
        height: day.px(36)
        radius: day.px(10)
        color: buttonHover.hovered ? day.chipFill : "transparent"

        Row {
            id: buttonRow

            anchors.centerIn: parent
            spacing: day.px(8)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: button.glyph !== ""
                text: button.glyph
                font.family: "Material Symbols Rounded"
                font.pixelSize: day.px(20)
                color: button.tint
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: button.label !== ""
                text: button.label
                textFormat: Text.PlainText
                font.family: "JetBrains Mono"
                font.pixelSize: day.px(13)
                color: button.tint
            }
        }

        HoverHandler { id: buttonHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: button.activated() }
        Accessible.role: Accessible.Button
        Accessible.name: button.name
    }

    // --- the ground -------------------------------------------------------

    // The design's `linear-gradient(160deg, ...)`, drawn as CSS draws it: a
    // line through the centre at that angle, long enough that its ends touch
    // the corners.
    Shape {
        id: ground

        anchors.fill: parent

        readonly property real dx: Math.sin(160 * Math.PI / 180)
        readonly property real dy: -Math.cos(160 * Math.PI / 180)
        readonly property real reach: (Math.abs(ground.width * ground.dx) + Math.abs(ground.height * ground.dy)) / 2

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: ground.width / 2 - ground.dx * ground.reach
                y1: ground.height / 2 - ground.dy * ground.reach
                x2: ground.width / 2 + ground.dx * ground.reach
                y2: ground.height / 2 + ground.dy * ground.reach
                GradientStop { position: 0; color: day.g0 }
                GradientStop { position: day.tone.stop; color: day.g1 }
                GradientStop { position: 1; color: day.g2 }
            }

            startX: 0
            startY: 0
            PathLine { x: ground.width; y: 0 }
            PathLine { x: ground.width; y: ground.height }
            PathLine { x: 0; y: ground.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // The board, at the design's width, centred on anything wider.
    Item {
        id: board

        width: Math.min(day.width, day.px(1920))
        height: day.height
        x: Math.round((day.width - board.width) / 2)

        readonly property real shownOpacity: day.ui.unlock.shown ? 1 : 0

        // --- the head -----------------------------------------------------

        Row {
            x: day.px(80)
            y: day.px(52)
            height: day.px(36)
            spacing: day.px(12)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: day.px(24)
                height: width
                radius: day.px(7)
                color: day.ui.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: day.ui.userName
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: day.px(16)
                font.weight: Font.Medium
                color: day.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: day.px(8)
                text: day.lockedAgo
                textFormat: Text.PlainText
                font.family: "JetBrains Mono"
                font.pixelSize: day.px(13)
                color: day.sub
            }
        }

        Row {
            x: board.width - width - day.px(80)
            y: day.px(52)
            spacing: day.px(4)
            opacity: board.shownOpacity
            enabled: day.ui.unlock.shown

            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

            StatusButton {
                visible: day.ui.keyboard?.status === Loader.Ready
                glyph: day.ui.keyboard?.keyboardActive ? "keyboard_hide" : "keyboard"
                name: "On-screen keyboard"
                onActivated: {
                    day.ui.focusPassword();
                    day.ui.keyboard.showHide();
                }
            }

            // The layout by its short name, as the design draws it; a press
            // is the next one. A layout that is not the person's first is in
            // the warning colour, as LockMessage says in words.
            StatusButton {
                visible: LockKeys.current !== null
                label: LockKeys.current?.shortName ?? ""
                tint: LockKeys.otherLayout ? day.warn : day.ink
                name: "Keyboard layout: " + LockKeys.layoutName
                onActivated: {
                    LockKeys.nextLayout();
                    day.ui.focusPassword();
                }
            }
        }

        // --- the clock ----------------------------------------------------

        Column {
            id: left

            x: day.px(80)
            y: day.px(150)
            width: day.px(640)
            spacing: 0

            Text {
                width: parent.width
                text: day.greeting + ", " + day.ui.userName
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: "Rubik"
                font.pixelSize: day.px(26)
                font.weight: Font.Light
                color: day.sub
            }

            Item {
                width: parent.width
                height: day.px(10)
            }

            Row {
                spacing: day.px(14)
                opacity: day.ui.showClock ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

                LockClock {
                    id: clock

                    showDate: false
                    raised: false
                    animated: !day.reduceMotion
                    ink: day.ink
                    timeSize: day.px(150)
                    timeWeight: Font.ExtraLight
                }

                Text {
                    y: day.px(30)
                    text: LockText.pad(clock.now.getSeconds())
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: day.px(20)
                    font.features: { "tnum": 1 }
                    color: day.sub
                }
            }

            Text {
                topPadding: day.px(4)
                opacity: day.ui.showClock ? 1 : 0
                text: clock.now.toLocaleDateString(Qt.locale(), "dddd d MMMM")
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: day.px(26)
                font.weight: Font.Light
                color: day.sub

                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
            }
        }

        // --- the day ------------------------------------------------------

        // Where the design lists today's events: the day the palette keeps,
        // dawn to dawn, as bands on a ruler, with the hour on it.
        Card {
            id: today

            x: day.px(780)
            y: day.px(150)
            width: day.px(580)
            height: board.height - y - day.px(72)

            Item {
                anchors.fill: parent
                anchors.leftMargin: day.px(26)
                anchors.rightMargin: day.px(26)
                anchors.topMargin: day.px(28)
                anchors.bottomMargin: day.px(22)

                Item {
                    id: todayHead

                    x: day.px(14)
                    width: parent.width - day.px(28)
                    height: Math.max(todayCaption.height, todayNext.height)

                    Caption {
                        id: todayCaption

                        anchors.baseline: todayNext.baseline
                        text: "TODAY · " + day.band.name.toUpperCase()
                    }

                    Text {
                        id: todayNext

                        anchors.right: parent.right
                        text: day.nextBand.key + " in " + day.dur(day.minsLeft)
                        textFormat: Text.PlainText
                        font.family: "Rubik"
                        font.pixelSize: day.px(14)
                        font.weight: Font.Medium
                        color: day.ink
                    }
                }

                Text {
                    id: todayTitle

                    x: day.px(14)
                    y: todayHead.height + day.px(8)
                    width: parent.width - day.px(28)
                    text: ({
                        "dawn": "Morning light until 09:00",
                        "day": "Daylight until 17:00",
                        "dusk": "Dusk until 20:00",
                        "night": "Night until 05:00",
                    })[day.phase]
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: "Rubik"
                    font.pixelSize: day.px(22)
                    color: day.ink
                }

                // The ruler. An hour is `step` tall; the palette's day starts
                // at 05:00 at the top and ends there at the bottom.
                Item {
                    id: ruler

                    y: todayTitle.y + todayTitle.height + day.px(24)
                    width: parent.width
                    height: todayFoot.y - y - day.px(16)

                    readonly property real step: ruler.height / 24
                    readonly property int timeX: day.px(14)
                    readonly property int railX: day.px(14 + 52 + 16)
                    readonly property int railW: day.px(10)
                    readonly property int textX: ruler.railX + ruler.railW + day.px(16)
                    readonly property real nowY: (day.cycleNow - 5) * ruler.step

                    function yOf(h: real): real {
                        return (h - 5) * ruler.step;
                    }

                    // The bands, as the design draws its event rows: the
                    // current one on a chip, the ones gone by faded.
                    Repeater {
                        model: day.bands

                        Item {
                            id: bandRow

                            required property var modelData
                            required property int index

                            readonly property bool current: bandRow.index === day.bandIndex
                            readonly property bool past: day.cycleNow >= bandRow.modelData.to
                            readonly property bool next: bandRow.index === (day.bandIndex + 1) % day.bands.length
                            readonly property var colours: day.palettes[bandRow.modelData.key]

                            y: ruler.yOf(bandRow.modelData.from) + 1
                            width: ruler.width
                            height: ruler.yOf(bandRow.modelData.to) - ruler.yOf(bandRow.modelData.from) - 2

                            Rectangle {
                                anchors.fill: parent
                                radius: day.px(16)
                                color: bandRow.current ? day.chipFill : "transparent"
                            }

                            // The rail, in the band's own colours: pale for
                            // the light phases, deep for the dark ones.
                            Rectangle {
                                x: ruler.railX
                                y: day.px(6)
                                width: ruler.railW
                                height: parent.height - day.px(12)
                                radius: width / 2
                                opacity: bandRow.past ? 0.55 : 1
                                border.width: 1
                                border.color: day.line
                                gradient: Gradient {
                                    GradientStop { position: 0; color: bandRow.colours.g0 }
                                    GradientStop { position: 1; color: bandRow.colours.g2 }
                                }
                            }

                            // The label stays clear of the "now" line:
                            // under it where the band has room, over it
                            // where it does not.
                            Column {
                                id: bandText

                                readonly property real rest: day.px(10)
                                readonly property real nowAt: ruler.nowY - bandRow.y
                                readonly property bool crossed: bandRow.current
                                    && bandText.nowAt > bandText.rest - day.px(8)
                                    && bandText.nowAt < bandText.rest + bandText.height + day.px(8)
                                readonly property real under: bandText.nowAt + day.px(12)

                                x: ruler.textX
                                y: !bandText.crossed ? bandText.rest
                                    : bandText.under + bandText.height <= bandRow.height - day.px(4) ? bandText.under
                                    : Math.max(day.px(2), bandText.nowAt - day.px(12) - bandText.height)
                                width: parent.width - x - day.px(14)
                                spacing: day.px(4)
                                opacity: bandRow.past ? 0.55 : 1

                                Row {
                                    spacing: day.px(10)

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: bandRow.modelData.glyph
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: day.px(18)
                                        color: day.ink
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: bandRow.modelData.name
                                        textFormat: Text.PlainText
                                        font.family: "Rubik"
                                        font.pixelSize: day.px(17)
                                        font.weight: Font.Medium
                                        color: day.ink
                                    }

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: bandRow.current || bandRow.next
                                        width: tag.implicitWidth + day.px(16)
                                        height: tag.implicitHeight + day.px(6)
                                        radius: height / 2
                                        color: day.ui.accent

                                        Text {
                                            id: tag

                                            anchors.centerIn: parent
                                            text: bandRow.current ? "NOW" : "NEXT"
                                            textFormat: Text.PlainText
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: day.px(10.5)
                                            font.weight: Font.Medium
                                            font.letterSpacing: day.px(0.8)
                                            color: "#ffffff"
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: day.at(bandRow.modelData.from) + "–" + day.at(bandRow.modelData.to) + " · "
                                        + (bandRow.current ? day.dur(day.minsLeft) + " left"
                                                           : day.dur((bandRow.modelData.to - bandRow.modelData.from) * 60))
                                        + " · " + (bandRow.colours.light ? "light" : "dark")
                                    textFormat: Text.PlainText
                                    font.family: "Rubik"
                                    font.pixelSize: day.px(13.5)
                                    color: day.sub
                                }
                            }
                        }
                    }

                    // The hours, down the time column. The one under the
                    // "now" mark gives way to it.
                    Repeater {
                        model: 24

                        Text {
                            id: hourLabel

                            required property int index
                            readonly property int h: 5 + hourLabel.index
                            readonly property bool edge: day.bands.some(b => b.from === hourLabel.h)

                            x: ruler.timeX
                            y: ruler.yOf(hourLabel.h) - height / 2
                            visible: Math.abs(ruler.yOf(hourLabel.h) - ruler.nowY) > day.px(20)
                            text: day.at(hourLabel.h)
                            textFormat: Text.PlainText
                            font.family: "JetBrains Mono"
                            font.pixelSize: day.px(hourLabel.edge ? 13 : 11)
                            color: day.sub
                            opacity: hourLabel.edge ? 1 : 0.55
                        }
                    }

                    // How long this screen has been locked, on the rail: from
                    // when it locked to now, or from dawn if it has been
                    // locked since before it.
                    Rectangle {
                        readonly property real from: (clock.now.getTime() - day.ui.lockedAt.getTime()) >= 24 * 3600000
                            || day.cycleOf(day.ui.lockedAt) > day.cycleNow
                            ? 0 : ruler.yOf(day.cycleOf(day.ui.lockedAt))

                        x: ruler.railX
                        y: Math.min(from, ruler.nowY - height)
                        width: ruler.railW
                        height: Math.max(ruler.railW, ruler.nowY - from)
                        radius: width / 2
                        color: Qt.alpha(day.ui.accent, 0.7)
                    }

                    // Now: a line across, a dot on the rail, the time in the
                    // time column.
                    Rectangle {
                        x: ruler.timeX + day.px(52)
                        y: ruler.nowY - height / 2
                        width: ruler.width - x - day.px(6)
                        height: Math.max(1, day.px(2))
                        color: day.ui.accent
                    }

                    Rectangle {
                        x: ruler.railX + ruler.railW / 2 - width / 2
                        y: ruler.nowY - height / 2
                        width: day.px(16)
                        height: width
                        radius: width / 2
                        color: day.ui.accent
                        border.width: day.px(3)
                        border.color: day.light ? "#ffffff" : day.g1
                    }

                    Text {
                        x: ruler.timeX
                        y: ruler.nowY - height / 2
                        text: LockText.pad(clock.now.getHours()) + ":" + LockText.pad(clock.now.getMinutes())
                        textFormat: Text.PlainText
                        font.family: "JetBrains Mono"
                        font.pixelSize: day.px(13)
                        font.weight: Font.Medium
                        color: day.ui.accent
                    }
                }

                Item {
                    id: todayFoot

                    x: day.px(14)
                    width: parent.width - day.px(28)
                    height: day.px(14) + footLeft.height
                    y: parent.height - height

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: day.line
                    }

                    Text {
                        id: footLeft

                        anchors.bottom: parent.bottom
                        text: day.light ? "Dark from 17:00"
                            : (day.hour >= 17 ? "Tomorrow · light" : "Light") + " again at 05:00"
                        textFormat: Text.PlainText
                        font.family: "Rubik"
                        font.pixelSize: day.px(13)
                        color: day.sub
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: "the colours follow the clock"
                        textFormat: Text.PlainText
                        font.family: "Rubik"
                        font.pixelSize: day.px(13)
                        color: day.sub
                    }
                }
            }
        }

        // --- the side -----------------------------------------------------

        // The design's right-hand stack, from the top: what is playing, then
        // this lock and the battery in the design's two-up card.
        Column {
            id: side

            x: day.px(1420)
            y: day.px(150)
            width: board.width - x - day.px(80)
            spacing: day.px(18)

            // What is playing, as the design's card: art, track, artist and
            // album, and the one button. Drawn here rather than by MediaCard
            // because it is another card -- one round button rather than
            // three, the album, art that waits on the accent's gradient --
            // and MediaCard taking all of that would be parameters only this
            // style sets. The rounded art is LockPicture, as the faces are.
            Repeater {
                model: day.ui.setting("showMediaControls", true) ? LockKeys.players : null

                Card {
                    id: player

                    required property var model

                    width: parent.width
                    height: day.px(84 + 44)
                    opacity: board.shownOpacity

                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

                    Rectangle {
                        id: artBack

                        x: day.px(22)
                        y: day.px(22)
                        width: day.px(84)
                        height: width
                        radius: day.px(16)
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#2b2f45" }
                            GradientStop { position: 0.55; color: day.ui.accent }
                            GradientStop { position: 1; color: "#e0b9a8" }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: "graphic_eq"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: day.px(28)
                            color: Qt.rgba(1, 1, 1, 0.8)
                        }
                    }

                    LockPicture {
                        id: art

                        anchors.fill: artBack
                        radius: artBack.radius
                        asynchronous: true
                        source: player.model.artUrl ?? ""
                        sourceSize: Qt.size(artBack.width * 2, artBack.height * 2)
                    }

                    Column {
                        anchors.left: artBack.right
                        anchors.leftMargin: day.px(18)
                        anchors.right: playButton.left
                        anchors.rightMargin: day.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: day.px(2)

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: (player.model.track ?? "").length > 0 ? player.model.track : "Nothing playing"
                            textFormat: Text.PlainText
                            font.family: "Rubik"
                            font.pixelSize: day.px(17)
                            font.weight: Font.Medium
                            color: day.ink
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: [player.model.artist || player.model.identity, player.model.album]
                                .filter(p => p).join(" · ")
                            textFormat: Text.PlainText
                            font.family: "Rubik"
                            font.pixelSize: day.px(13)
                            color: day.sub
                        }
                    }

                    Text {
                        id: playButton

                        anchors.right: parent.right
                        anchors.rightMargin: day.px(22)
                        anchors.verticalCenter: parent.verticalCenter
                        text: player.model.playbackStatus === Mpris.PlaybackStatus.Playing ? "pause_circle" : "play_circle"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: day.px(40)
                        color: day.ink
                        opacity: playTap.pressed ? 0.6 : 1

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            id: playTap
                            enabled: player.model.canControl && day.ui.unlock.shown
                            onTapped: player.model.container.PlayPause()
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: "Play or pause"
                    }
                }
            }

            // Where the design has its battery and disk: when this screen
            // locked and how many passwords it has refused since, which the
            // greeter does know, and the battery under them when there is one.
            Card {
                width: parent.width
                height: (batteryBody.visible ? batteryBody.y + batteryBody.height : lockGrid.y + lockGrid.height) + day.px(22)

                Grid {
                    id: lockGrid

                    x: day.px(24)
                    y: day.px(22)
                    width: parent.width - day.px(48)
                    columns: 2
                    columnSpacing: day.px(20)
                    rowSpacing: day.px(18)

                    readonly property int cell: Math.floor((lockGrid.width - lockGrid.columnSpacing) / 2)

                    Column {
                        width: lockGrid.cell
                        spacing: day.px(6)

                        Caption {
                            text: "LOCKED AT"
                        }

                        Figure {
                            value: day.lockedTime
                        }
                    }

                    Column {
                        width: lockGrid.cell
                        spacing: day.px(6)

                        Caption {
                            text: "REFUSED"
                        }

                        Figure {
                            value: String(day.ui.unlock.refusals)
                            note: day.ui.unlock.refusals === 1 ? "password" : "passwords"
                            tint: day.ui.unlock.refusals > 0 ? day.bad : day.ink
                        }
                    }
                }

                Column {
                    id: batteryBody

                    x: day.px(24)
                    y: lockGrid.y + lockGrid.height + day.px(18)
                    width: parent.width - day.px(48)
                    spacing: day.px(6)
                    visible: day.battery.present

                    Caption {
                        text: "BATTERY"
                    }

                    Figure {
                        value: day.battery.percent + "%"
                        note: day.batteryLine
                    }

                    Rectangle {
                        width: parent.width
                        height: day.px(4)
                        radius: height / 2
                        color: day.line

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(100, day.battery.percent)) / 100
                            height: parent.height
                            radius: height / 2
                            color: day.battery.percent <= 15 && !day.battery.plugged ? day.bad : "#7fb98a"
                        }
                    }
                }
            }
        }

        // Sleep, hibernate, switch user. The design has no place for them;
        // they sit at the foot of the right-hand column, level with the
        // password, in the reminders' card and voice.
        Card {
            x: side.x
            y: board.height - height - day.px(72)
            width: side.width
            height: sessionBody.height + day.px(44)
            visible: Options.showSessionButtons
                && (day.ui.session.canSuspend || day.ui.session.canHibernate || day.ui.session.canSwitchUser)
            opacity: board.shownOpacity

            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

            Column {
                id: sessionBody

                x: day.px(24)
                y: day.px(22)
                width: parent.width - day.px(48)
                spacing: day.px(14)

                Caption {
                    text: "SESSION"
                }

                LockActions {
                    enabled: day.ui.unlock.shown
                    session: day.ui.session
                    shape: "round"
                    unit: day.unit
                    size: day.px(48)
                    spacing: day.px(12)
                    ink: day.ink
                    fill: day.chipFill
                    stroke: day.line
                    hot: day.line
                }
            }
        }

        // --- the prompt ---------------------------------------------------

        LockMessage {
            x: pill.x + day.px(8)
            y: pill.y - height - day.px(16)
            width: pill.width - day.px(16)
            opacity: pill.opacity
            unlock: day.ui.unlock
            unit: day.unit
            align: Text.AlignLeft
            ink: day.ink
            warn: day.warn
        }

        // The design's pill: the face, the name over one line of state, the
        // field, and the round arrow.
        Rectangle {
            id: pill

            x: day.px(80)
            y: board.height - height - day.px(72)
            width: day.px(640)
            height: day.px(84)
            radius: day.px(26)
            color: day.cardFill
            border.width: Math.max(1, day.px(1.5))
            border.color: password.stateBorder
            opacity: board.shownOpacity

            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
            }

            // The design's avatar gradient runs at 135 degrees; a circle
            // turned 45 turns its gradient without changing its shape.
            Rectangle {
                id: avatar

                x: day.px(16)
                anchors.verticalCenter: parent.verticalCenter
                width: day.px(52)
                height: width
                radius: width / 2
                rotation: -45
                gradient: Gradient {
                    GradientStop { position: 0; color: "#b9c3e8" }
                    GradientStop { position: 1; color: "#e5cdbb" }
                }
            }

            LockFace {
                anchors.fill: avatar
                image: day.ui.userImage
                userName: day.ui.userName
                ink: "#3d3a35"
                fill: "transparent"
                ring: "transparent"
                ringWidth: 0
            }

            Column {
                id: who

                anchors.left: avatar.right
                anchors.leftMargin: day.px(16)
                anchors.verticalCenter: parent.verticalCenter
                width: day.px(170)
                spacing: day.px(2)

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: day.ui.userName
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: day.px(16)
                    font.weight: Font.Medium
                    color: day.ink
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: day.ui.unlock.resting ? "wait a moment"
                        : day.ui.unlock.refusals > 0 ? day.ui.unlock.refusals + " refused · try again"
                        : "password · enter ⏎"
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: day.px(12)
                    color: day.ui.unlock.refusals > 0 && !day.ui.unlock.resting ? day.bad : day.sub
                }
            }

            LockPrompt {
                id: password

                anchors.left: who.right
                anchors.leftMargin: day.px(16)
                anchors.right: go.visible ? go.left : parent.right
                anchors.rightMargin: day.px(12)
                anchors.verticalCenter: parent.verticalCenter
                unlock: day.ui.unlock
                unit: day.unit
                chrome: "none"
                glyph: ""
                placeholder: "Password"
                showButton: false
                ink: day.ink
                dim: day.sub
                accent: day.ui.accent
                errorColor: day.bad
                alarm: day.ui.unlock.message.length > 0
            }

            Rectangle {
                id: go

                anchors.right: parent.right
                anchors.rightMargin: day.px(12)
                anchors.verticalCenter: parent.verticalCenter
                visible: password.takesPassword
                width: day.px(56)
                height: width
                radius: width / 2
                color: day.ui.accent
                opacity: day.ui.unlock.resting ? 0.5 : (goHover.hovered ? 0.88 : 1)

                Text {
                    anchors.centerIn: parent
                    text: LayoutMirroring.enabled ? "arrow_back" : "arrow_forward"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: day.px(26)
                    color: "#ffffff"
                }

                HoverHandler { id: goHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    enabled: !day.ui.unlock.resting
                    onTapped: password.submit()
                }
                Accessible.role: Accessible.Button
                Accessible.name: "Unlock"
            }
        }
    }
}
