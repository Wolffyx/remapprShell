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

    This file is the board; its parts are the DayAhead* files beside it --
    the palette and its day, the ground, the middle card and its ruler, the
    player and the lock's own card on the right, and the pill that takes the
    password.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

LockStyle {
    id: day

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: pill.field
    promptBlock: pill

    // --- the palette ------------------------------------------------------

    // The design's phases, the one the hour is in, and its colours easing
    // into the next one's. Every part below is drawn from it.
    readonly property int hour: clock.now.getHours()
    readonly property DayAheadPalette colours: DayAheadPalette {
        hour: day.hour
        reduceMotion: day.reduceMotion
    }

    // --- time -------------------------------------------------------------

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

    // --- the ground -------------------------------------------------------

    DayAheadGround {
        anchors.fill: parent
        colours: day.colours
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
                color: day.colours.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: day.px(8)
                text: day.lockedAgo
                textFormat: Text.PlainText
                font.family: "JetBrains Mono"
                font.pixelSize: day.px(13)
                color: day.colours.sub
            }
        }

        Row {
            x: board.width - width - day.px(80)
            y: day.px(52)
            spacing: day.px(4)
            opacity: board.shownOpacity
            enabled: day.ui.unlock.shown

            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

            DayAheadStatusButton {
                visible: day.ui.keyboardAvailable
                colours: day.colours
                unit: day.unit
                glyph: day.ui.keyboardShown ? "keyboard_hide" : "keyboard"
                name: "On-screen keyboard"
                onActivated: day.ui.toggleKeyboard()
            }

            // The layout by its short name, as the design draws it; a press
            // is the next one. A layout that is not the person's first is in
            // the warning colour, as LockMessage says in words.
            DayAheadStatusButton {
                visible: LockKeys.current !== null
                colours: day.colours
                unit: day.unit
                label: LockKeys.current?.shortName ?? ""
                tint: LockKeys.otherLayout ? day.colours.warn : day.colours.ink
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
                color: day.colours.sub
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
                    ink: day.colours.ink
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
                    color: day.colours.sub
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
                color: day.colours.sub

                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
            }
        }

        // --- the day ------------------------------------------------------

        DayAheadToday {
            x: day.px(780)
            y: day.px(150)
            width: day.px(580)
            height: board.height - y - day.px(72)
            colours: day.colours
            unit: day.unit
            accent: day.ui.accent
            now: clock.now
            lockedAt: day.ui.lockedAt
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

            Repeater {
                model: day.ui.setting("showMediaControls", true) ? LockKeys.players : null

                DayAheadPlayer {
                    width: parent.width
                    opacity: board.shownOpacity
                    ui: day.ui
                    colours: day.colours
                    unit: day.unit

                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                }
            }

            DayAheadLockCard {
                width: parent.width
                ui: day.ui
                colours: day.colours
                unit: day.unit
            }
        }

        // Sleep, hibernate, switch user. The design has no place for them;
        // they sit at the foot of the right-hand column, level with the
        // password, in the reminders' card and voice.
        DayAheadCard {
            x: side.x
            y: board.height - height - day.px(72)
            width: side.width
            height: sessionBody.height + day.px(44)
            colours: day.colours
            unit: day.unit
            // The row's `any`, not its `visible`: a child reads as hidden for
            // as long as its card is, so a card that asked could never
            // come back.
            visible: sessionActions.any
            opacity: board.shownOpacity

            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

            Column {
                id: sessionBody

                x: day.px(24)
                y: day.px(22)
                width: parent.width - day.px(48)
                spacing: day.px(14)

                DayAheadCaption {
                    colours: day.colours
                    unit: day.unit
                    text: "SESSION"
                }

                LockActions {
                    id: sessionActions

                    enabled: day.ui.unlock.shown
                    session: day.ui.session
                    shape: "round"
                    unit: day.unit
                    size: day.px(48)
                    spacing: day.px(12)
                    ink: day.colours.ink
                    fill: day.colours.chipFill
                    stroke: day.colours.line
                    hot: day.colours.line
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
            ink: day.colours.ink
            warn: day.colours.warn
        }

        DayAheadPill {
            id: pill

            x: day.px(80)
            y: board.height - height - day.px(72)
            width: day.px(640)
            ui: day.ui
            colours: day.colours
            unit: day.unit
            opacity: board.shownOpacity

            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
            }
        }
    }
}
