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
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

LockStyle {
    id: kiosk

    readonly property real unit: kiosk.ui.unit

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

    promptField: password
    promptBlock: staff

    Rectangle {
        anchors.fill: parent
        color: kiosk.paper
    }

    // One of the design's white chips: a glyph and a word.
    component Chip: Rectangle {
        id: chip

        property string glyph: ""
        property string label: ""
        property bool checked: false
        property bool plain: false
        signal activated

        width: chipRow.implicitWidth + Math.round(32 * kiosk.textUnit)
        height: chipRow.implicitHeight + Math.round(22 * kiosk.textUnit)
        radius: Math.round(12 * kiosk.unit)
        color: chip.checked ? kiosk.ink
             : chip.plain ? (chipHover.hovered ? kiosk.hair : "transparent")
             : (chipHover.hovered ? "#f8f5f0" : kiosk.card)
        border.width: chip.plain ? 0 : 1
        border.color: kiosk.hair

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: Math.round(9 * kiosk.textUnit)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                font.family: "Material Symbols Rounded"
                font.pixelSize: Math.round(20 * kiosk.textUnit)
                color: chip.checked ? kiosk.card : chip.plain ? kiosk.sub : kiosk.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: Math.round(14 * kiosk.textUnit)
                color: chip.checked ? kiosk.card : chip.plain ? kiosk.sub : kiosk.ink
            }
        }

        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: chip.activated() }
        Accessible.role: Accessible.Button
        Accessible.name: chip.label
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

    Column {
        id: welcome

        x: kiosk.ui.edge
        // The design's 210, unless larger text needs the room above the foot.
        y: Math.max(brand.y + brand.height + Math.round(40 * kiosk.unit),
                    Math.min(Math.round(210 * kiosk.unit), foot.y - height - Math.round(48 * kiosk.unit)))
        width: Math.round(920 * kiosk.unit)
        spacing: 0

        Text {
            width: parent.width
            text: kiosk.canGuest ? "Welcome.\nUse this computer\nas a guest."
                                 : "Welcome.\nThis computer is\nlocked for now."
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            lineHeightMode: Text.FixedHeight
            lineHeight: Math.round(87 * kiosk.unit)
            font.family: "Rubik"
            font.pixelSize: Math.round(84 * kiosk.unit)
            font.weight: Font.Light
            font.letterSpacing: -Math.round(2.5 * kiosk.unit)
            color: kiosk.ink
        }

        Item { width: 1; height: Math.round(24 * kiosk.unit); visible: lede.visible }

        Text {
            id: lede

            width: Math.round(760 * kiosk.unit)
            visible: kiosk.canGuest
            text: "Start your own session from the login screen. Whoever was here before stays locked and private."
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            lineHeightMode: Text.FixedHeight
            lineHeight: Math.round(31 * kiosk.textUnit)
            font.family: "Rubik"
            font.pixelSize: Math.round(21 * kiosk.textUnit)
            color: kiosk.sub
        }

        Item { width: 1; height: Math.round(44 * kiosk.unit); visible: guest.visible }

        // The one big action.
        Rectangle {
            id: guest

            visible: kiosk.canGuest
            width: Math.round(640 * kiosk.unit) + (kiosk.larger ? Math.round(120 * kiosk.unit) : 0)
            height: Math.max(Math.round(104 * kiosk.unit), guestText.implicitHeight + Math.round(40 * kiosk.unit))
            radius: Math.round(26 * kiosk.unit)
            color: guestHover.hovered ? Qt.lighter(kiosk.accent, 1.1) : kiosk.accent

            Text {
                id: guestGlyph

                x: Math.round(36 * kiosk.unit)
                anchors.verticalCenter: parent.verticalCenter
                text: "play_arrow"
                font.family: "Material Symbols Rounded"
                font.pixelSize: Math.round(36 * kiosk.textUnit)
                color: "#ffffff"
            }

            Column {
                id: guestText

                anchors.left: guestGlyph.right
                anchors.leftMargin: Math.round(16 * kiosk.unit)
                anchors.right: parent.right
                anchors.rightMargin: Math.round(22 * kiosk.unit)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(4 * kiosk.unit)

                Text {
                    width: parent.width
                    text: "Start a guest session"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: "Rubik"
                    font.pixelSize: Math.round(30 * kiosk.textUnit)
                    font.weight: Font.Medium
                    color: "#ffffff"
                }

                Text {
                    width: parent.width
                    text: "Opens the login screen for a guest to sign in · this session stays locked"
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    font.family: "Rubik"
                    font.pixelSize: Math.round(15 * kiosk.textUnit)
                    color: Qt.rgba(1, 1, 1, 0.84)
                }
            }

            HoverHandler { id: guestHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: kiosk.ui.session.switchUser() }
            Accessible.role: Accessible.Button
            Accessible.name: "Start a guest session"
            Accessible.description: "Opens the login screen for a guest to sign in. This session stays locked."
        }

        Item { width: 1; height: Math.round(48 * kiosk.unit); visible: note.visible }

        // The house rule: one, the place's own, or none at all.
        Rectangle {
            id: note

            visible: Options.kioskNote !== ""
            width: guest.visible ? guest.width : Math.round(640 * kiosk.unit)
            height: noteRow.height + Math.round(44 * kiosk.unit)
            radius: Math.round(20 * kiosk.unit)
            color: kiosk.card
            border.width: 1
            border.color: kiosk.hair

            Row {
                id: noteRow

                x: Math.round(22 * kiosk.unit)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * x
                spacing: Math.round(16 * kiosk.unit)

                Text {
                    id: noteGlyph

                    anchors.verticalCenter: parent.verticalCenter
                    text: "info"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Math.round(26 * kiosk.textUnit)
                    color: kiosk.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: noteRow.width - noteGlyph.width - noteRow.spacing
                    text: Options.kioskNote
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    font.family: "Rubik"
                    font.pixelSize: Math.round(17 * kiosk.textUnit)
                    color: kiosk.ink
                }
            }
        }
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

    Rectangle {
        id: staff

        x: kiosk.width - width - kiosk.ui.edge
        y: foot.y - height - Math.round(14 * kiosk.unit)
        width: Math.round(460 * kiosk.textUnit)
        height: staffColumn.height + Math.round(48 * kiosk.unit)
        radius: Math.round(22 * kiosk.unit)
        color: kiosk.card
        border.width: 1
        border.color: kiosk.hair
        enabled: kiosk.ui.unlock.shown
        opacity: kiosk.ui.unlock.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }

        Column {
            id: staffColumn

            x: Math.round(24 * kiosk.unit)
            y: Math.round(24 * kiosk.unit)
            width: staff.width - 2 * x
            spacing: Math.round(14 * kiosk.unit)

            Item {
                width: parent.width
                height: Math.max(staffTitle.height, status.height)

                Column {
                    id: staffTitle

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(3 * kiosk.unit)

                    Text {
                        text: "Staff sign-in"
                        textFormat: Text.PlainText
                        font.family: "Rubik"
                        font.pixelSize: Math.round(17 * kiosk.textUnit)
                        font.weight: Font.Medium
                        color: kiosk.ink
                    }

                    // Whose session a right password opens.
                    Text {
                        text: "Unlocks " + kiosk.ui.userName + "’s session"
                        textFormat: Text.PlainText
                        font.family: "Rubik"
                        font.pixelSize: Math.round(13 * kiosk.textUnit)
                        color: kiosk.sub
                    }
                }

                LockStatus {
                    id: status

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    keyboard: kiosk.ui.keyboard
                    ink: kiosk.sub
                    warn: "#8a5a20"
                    textSize: Math.round(12 * kiosk.textUnit)
                    spacing: Math.round(10 * kiosk.unit)
                    onFocusRequested: kiosk.ui.focusPassword()
                }
            }

            LockPrompt {
                id: password

                width: parent.width
                height: Math.round(52 * kiosk.textUnit)
                unlock: kiosk.ui.unlock
                unit: kiosk.textUnit
                glyph: "password"
                showButton: false
                radius: Math.round(12 * kiosk.unit)
                ink: kiosk.ink
                dim: kiosk.sub
                accent: kiosk.accent
                fieldColor: "#f5f1ea"
                fieldBorder: kiosk.accent
            }

            // The hint, then whatever went wrong. Close together, so that an
            // empty message costs the card next to nothing.
            Column {
                width: parent.width
                spacing: Math.round(6 * kiosk.unit)

                Text {
                    width: parent.width
                    text: kiosk.ui.unlock.resting ? "too many attempts · wait a moment" : "password · enter ⏎"
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(13 * kiosk.textUnit)
                    color: kiosk.sub
                }

                LockMessage {
                    width: parent.width
                    unlock: kiosk.ui.unlock
                    unit: kiosk.textUnit
                    align: Text.AlignLeft
                    ink: kiosk.ink
                    warn: "#8a5a20"
                }
            }
        }
    }
}
