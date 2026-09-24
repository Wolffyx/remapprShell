/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Kiosk (4b) -- a shared public computer: one big guest action, the house
    rule, and the staff's own sign-in pushed into a corner rather than the
    centre.

    The guest action is real. It is the greeter's switch-user, which opens the
    display manager's login screen for somebody else to sign in -- a guest
    account, where the machine has one -- while the session locked here stays
    locked. Where the machine cannot switch users there is no button, and the
    welcome says the computer is locked rather than offering what it cannot
    do. The staff sign-in is this lock's own password field, for the account
    that locked it, and says whose that is.

    The place's name and its one notice are settings (`kioskName`,
    `kioskNote`). An empty name is "Shared computer"; an empty notice draws no
    card at all.

    Most of the design is not drawn, because the greeter cannot know it: the
    terminal number and floor, the reservations and the day's availability
    bar, the list of what is installed "on this terminal", and the three house
    rules -- a sixty-minute limit, twenty free pages, and everything being
    wiped at logout are the library's policies, not this machine's, and a
    lock screen promising a wipe it does not perform would be the worst of
    them. The "Preparing a fresh session" progress is not drawn either: the
    login screen is the display manager's, and nothing here sees it start.
    The language chips are gone, since the greeter cannot change language
    mid-lock, and so are "Accessibility", which would have no settings window
    to open, and "Read aloud", since the greeter has no speech. "Larger text"
    stays: it enlarges this style's own type, for this lock only.

    This file is the page and its head and foot; the welcome and the staff
    sign-in are KioskWelcome and KioskStaff, and the chips are KioskChip.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

LockStyle {
    id: kiosk

    // "Larger text", for this lock only: every line of reading size is drawn
    // a quarter larger. The headline is already as large as the page allows.
    property bool larger: false
    readonly property real textUnit: kiosk.unit * (kiosk.larger ? 1.25 : 1)

    readonly property color paper: "#f1ece4"
    readonly property color ink: "#211e1a"
    readonly property color sub: "#5a534b"
    readonly property color card: "#ffffff"
    readonly property color hair: Qt.rgba(0.13, 0.12, 0.1, 0.08)
    readonly property color accent: kiosk.ui.accent

    readonly property bool canGuest: kiosk.ui.session.canSwitchUser
    readonly property string place: Options.kioskName !== "" ? Options.kioskName : "Shared computer"

    // A light page with dark type: the frame's blur and its darkening scrim
    // would only muddy it.
    blursWallpaper: false
    scrimsWallpaper: false

    promptField: staff.field
    promptBlock: staff

    Rectangle {
        anchors.fill: parent
        color: kiosk.paper
    }

    component Chip: KioskChip {
        unit: kiosk.unit
        textUnit: kiosk.textUnit
        ink: kiosk.ink
        sub: kiosk.sub
        card: kiosk.card
        hair: kiosk.hair
    }

    // --- the head ---------------------------------------------------------

    Row {
        id: brand

        x: kiosk.ui.edge
        y: Math.round(56 * kiosk.unit)
        spacing: Math.round(14 * kiosk.unit)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(44 * kiosk.unit)
            height: width
            radius: Math.round(13 * kiosk.unit)
            color: kiosk.accent

            Text {
                anchors.centerIn: parent
                text: "local_library"
                font.family: "Material Symbols Rounded"
                font.pixelSize: Math.round(24 * kiosk.unit)
                color: "#ffffff"
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(2 * kiosk.unit)

            Text {
                text: kiosk.place
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: Math.round(19 * kiosk.textUnit)
                font.weight: Font.Medium
                color: kiosk.ink
            }

            Text {
                text: kiosk.canGuest ? "GUEST MODE" : "LOCKED"
                textFormat: Text.PlainText
                font.family: "JetBrains Mono"
                font.pixelSize: Math.round(12 * kiosk.textUnit)
                font.letterSpacing: Math.round(1.2 * kiosk.textUnit)
                color: kiosk.sub
            }
        }
    }

    // The time, where the design has it, and the date under it in the same
    // small capitals as the line under the name.
    Column {
        anchors.right: parent.right
        anchors.rightMargin: kiosk.ui.edge
        anchors.verticalCenter: brand.verticalCenter
        spacing: Math.round(2 * kiosk.unit)
        opacity: kiosk.ui.showClock ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        LockClock {
            id: clock

            anchors.right: parent.right
            raised: false
            showDate: false
            ink: kiosk.ink
            timeSize: Math.round(30 * kiosk.unit)
            timeWeight: Font.Normal
        }

        Text {
            anchors.right: parent.right
            text: clock.now.toLocaleDateString(Qt.locale(), "dddd d MMMM").toUpperCase()
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(12 * kiosk.textUnit)
            font.letterSpacing: Math.round(1.2 * kiosk.textUnit)
            color: kiosk.sub
        }
    }

    // --- the welcome ------------------------------------------------------

    KioskWelcome {
        x: kiosk.ui.edge
        // The design's 210, unless larger text needs the room above the foot.
        y: Math.max(brand.y + brand.height + Math.round(40 * kiosk.unit),
                    Math.min(Math.round(210 * kiosk.unit), foot.y - height - Math.round(48 * kiosk.unit)))
        width: Math.round(920 * kiosk.unit)
        ui: kiosk.ui
        unit: kiosk.unit
        textUnit: kiosk.textUnit
        larger: kiosk.larger
        canGuest: kiosk.canGuest
        ink: kiosk.ink
        sub: kiosk.sub
        card: kiosk.card
        hair: kiosk.hair
        accent: kiosk.accent
    }

    // --- the foot ---------------------------------------------------------

    Item {
        id: foot

        x: kiosk.ui.edge
        width: kiosk.width - 2 * x
        height: Math.max(largerChip.height, staffChip.height)
        y: kiosk.height - height - Math.round(56 * kiosk.unit)
        enabled: kiosk.ui.unlock.shown

        Chip {
            id: largerChip

            anchors.verticalCenter: parent.verticalCenter
            glyph: "text_increase"
            label: "Larger text"
            checked: kiosk.larger
            Accessible.checkable: true
            Accessible.checked: kiosk.larger
            onActivated: {
                kiosk.larger = !kiosk.larger;
                kiosk.ui.focusPassword();
            }
        }

        // Staff sign in from here. The field above it is up whenever the
        // prompt is, and has the keyboard all along; this only puts the
        // caret back in it.
        Chip {
            id: staffChip

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glyph: "badge"
            label: "Staff sign-in"
            plain: !kiosk.ui.unlock.shown
            onActivated: {
                kiosk.ui.unlock.poke();
                kiosk.ui.focusPassword();
            }
        }
    }

    // --- the staff sign-in ------------------------------------------------

    KioskStaff {
        id: staff

        x: kiosk.width - width - kiosk.ui.edge
        y: foot.y - height - Math.round(14 * kiosk.unit)
        width: Math.round(460 * kiosk.textUnit)
        ui: kiosk.ui
        unit: kiosk.unit
        textUnit: kiosk.textUnit
        ink: kiosk.ink
        sub: kiosk.sub
        card: kiosk.card
        hair: kiosk.hair
        accent: kiosk.accent
        enabled: kiosk.ui.unlock.shown
        opacity: kiosk.ui.unlock.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }
    }
}
