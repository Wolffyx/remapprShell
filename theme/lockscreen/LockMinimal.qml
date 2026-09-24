/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Minimal (4a) -- the clock, and nothing else until you ask. The field
    fades up from under it when a key is pressed or the pointer moves, and
    goes again when the prompt does.

    The ground is its own, not the wallpaper: a flat paper, dark or light.
    Which one follows the colour scheme the person chose -- the greeter can
    read that much, through Kirigami -- and the round button at the top right
    turns it over, for this lock only: the greeter cannot write a file, and
    a setting that lasted would have to be one.

    The design's field says the login name at its end, in monospace; this
    one says the name the greeter was given. Under it is whatever PAM or the
    keyboard has to say, and nothing when there is nothing -- the design's
    resting line, "password · enter", only repeats what the field is.

    Not drawn from the design: its eight seconds. The prompt hides when the
    frame's own idle timer says so, as it does in every style, rather than
    on a second clock of its own.

    Not drawn at all: sleep, hibernate and switch user, whatever
    `showSessionButtons` says. The design has none, and the one it would
    need first -- sleep -- is a moon, the same moon as the toggle above it
    on a light screen. Two identical glyphs that do different things are
    worse than one missing; the machine's own power button still sleeps it.
    The status row is drawn, small, beside the toggle and only while the
    field is up: the on-screen keyboard is the only way in for somebody
    without a physical one.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

LockStyle {
    id: minimal

    readonly property bool shown: minimal.ui.unlock.shown

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: password
    promptBlock: promptColumn

    // --- light or dark ----------------------------------------------------

    // The person's colour scheme, as a window would be drawn in it. The frame
    // asks Kirigami for the complementary set, which is dark whatever was
    // chosen; this asks for the one that is not.
    Item {
        id: scheme

        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: Kirigami.Theme.Window

        readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5
    }

    // The toggle's, for this lock. Turns the scheme's answer over rather than
    // replacing it, so that it always means "the other one".
    property bool flipped: false
    readonly property bool dark: scheme.light === minimal.flipped

    property color paper: minimal.dark ? "#0d0c0b" : "#efe9e1"
    property color ink: minimal.dark ? "#ece6dd" : "#1f1c19"
    property color sub: minimal.dark ? "#8f877d" : "#5c554d"
    property color line: minimal.dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0.12, 0.11, 0.1, 0.18)

    Behavior on paper { ColorAnimation { duration: 600 } }
    Behavior on ink { ColorAnimation { duration: 600 } }
    Behavior on sub { ColorAnimation { duration: 600 } }
    Behavior on line { ColorAnimation { duration: 600 } }

    // The underline while it has a password: the accent, or the design's red
    // for as long as a refused one rests.
    readonly property color rule: minimal.ui.unlock.resting ? "#e0786a" : minimal.ui.accent

    Rectangle {
        anchors.fill: parent
        color: minimal.paper
    }

    // --- the top right ----------------------------------------------------

    Rectangle {
        id: toggle

        x: minimal.width - width - Math.round(56 * minimal.unit)
        y: Math.round(52 * minimal.unit)
        width: Math.round(44 * minimal.unit)
        height: width
        radius: width / 2
        color: toggleHover.hovered ? minimal.line : "transparent"
        border.width: 1
        border.color: minimal.line

        Accessible.role: Accessible.Button
        Accessible.name: minimal.dark ? "Use light colours" : "Use dark colours"

        Text {
            anchors.centerIn: parent
            text: minimal.dark ? "light_mode" : "dark_mode"
            font.family: "Material Symbols Rounded"
            font.pixelSize: Math.round(20 * minimal.unit)
            color: minimal.ink
        }

        HoverHandler { id: toggleHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                minimal.flipped = !minimal.flipped;
                minimal.ui.focusPassword();
            }
        }
    }

    LockStatus {
        x: toggle.x - width - Math.round(20 * minimal.unit)
        anchors.verticalCenter: toggle.verticalCenter
        enabled: minimal.shown
        opacity: promptColumn.opacity
        ui: minimal.ui
        ink: minimal.sub
        textSize: Math.round(12 * minimal.unit)
    }

    // --- the clock --------------------------------------------------------

    // The design sets the time a line exactly as tall as the type; Qt's line
    // is the font's own, taller by the ascender's air above and the
    // descender's below. Measured, so that the digits land where the design
    // puts them rather than where a line box would.
    readonly property int clockSize: Math.round(300 * minimal.unit)
    readonly property int dateSize: Math.round(24 * minimal.unit)

    FontMetrics {
        id: clockMetrics
        font.family: "Rubik"
        font.pixelSize: minimal.clockSize
        font.weight: Font.ExtraLight
    }

    readonly property real clockAir: (clockMetrics.height - minimal.clockSize) / 2

    LockClock {
        x: (minimal.width - width) / 2
        y: Math.round(280 * minimal.unit - minimal.clockAir)
        centred: true
        raised: false
        opacity: minimal.ui.showClock ? 1 : 0
        ink: minimal.ink
        dateInk: minimal.sub
        timeSize: minimal.clockSize
        dateSize: minimal.dateSize
        // The date 26 px under the type, not under the line: the air below
        // the digits and the clock's own padding are taken back.
        spacing: Math.round(26 * minimal.unit - minimal.clockAir - minimal.dateSize * 0.64)

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
    }

    // --- the field --------------------------------------------------------

    Column {
        id: promptColumn

        // The field stays where it is when a message comes: placed as though
        // the design's one line were always under it, and anything longer
        // hangs further down into the room the hint leaves.
        x: (minimal.width - width) / 2
        y: minimal.height - Math.round((150 + 16 + 16) * minimal.unit) - fieldRow.height
        width: Math.round(340 * minimal.unit)
        spacing: Math.round(16 * minimal.unit)
        opacity: minimal.shown ? 1 : 0
        transform: Translate {
            y: minimal.shown ? 0 : Math.round(12 * minimal.unit)
            Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        }

        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }

        // The field and, at its end, whose it is -- on one line, as the
        // design draws them.
        Item {
            id: fieldRow

            width: parent.width
            height: password.height

            LockPrompt {
                id: password

                width: fieldRow.width - (who.visible ? who.width + Math.round(14 * minimal.unit) : 0)
                unlock: minimal.ui.unlock
                unit: minimal.unit
                chrome: "underline"
                glyph: ""
                showButton: false
                ink: minimal.ink
                dim: minimal.sub
                accent: minimal.ui.accent
                fieldBorder: minimal.rule
            }

            // The underline goes on under the name: the prompt draws its own
            // only as wide as the field.
            Rectangle {
                anchors.left: password.right
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.max(1, Math.round(1.5 * minimal.unit))
                visible: password.takesPassword
                color: minimal.rule
            }

            Text {
                id: who

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Math.round(140 * minimal.unit))
                visible: minimal.ui.userName !== ""
                text: minimal.ui.userName
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: "JetBrains Mono"
                font.pixelSize: Math.round(12 * minimal.unit)
                color: minimal.sub
            }
        }

        LockMessage {
            width: parent.width
            unlock: minimal.ui.unlock
            unit: minimal.unit
            ink: minimal.sub
            warn: minimal.dark ? "#e0c98a" : "#8a5a20"
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: minimal.height - height - Math.round(110 * minimal.unit)
        opacity: minimal.shown ? 0 : 1
        text: "type or click to unlock"
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"
        font.pixelSize: Math.round(13 * minimal.unit)
        color: minimal.sub

        Behavior on opacity { NumberAnimation { duration: 450 } }
    }
}
