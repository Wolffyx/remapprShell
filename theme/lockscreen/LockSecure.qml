/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Secure workstation (3b) -- dark, monospace and auditable: a header bar, a
    big clock with its seconds, the way in on the left, and a rail on the
    right that says what is going on with this lock.

    The design leads with a hardware key -- insert, touch, then a PIN -- and
    keeps the password as the fallback. That flow is PAM's, not ours:
    kscreenlocker runs its fingerprint and smartcard authenticators beside the
    password one, and what they have to say arrives as the same messages the
    password's do. So the method tabs appear only when the greeter says such
    an authenticator exists; the key panel then asks for the key and shows
    PAM's own words under it. There are no simulated steps, no PIN pad of our
    own and no serial number: a PIN typed into a pad here would go nowhere,
    and a serial drawn from nowhere would be a lie about the key in the port.
    With no alternative configured there are no tabs, only the password.

    The design's right rail is device posture, enrolled keys, a journald log
    of sign-ins, VPN and Wi-Fi, and a "managed by IT" line. The greeter can
    read none of that -- it has no session, no bus to logind's history and no
    network -- so the rail says what it can know instead: which ways in PAM
    offers here, a log of this lock alone (when it locked, each refused
    password, each thing PAM said), the keyboard layout and the battery. The
    header's asset tag, the account's host and groups, the help-desk line and
    the idle-policy reason for locking go for the same reason. Restart and
    power off go too: the greeter can sleep, hibernate and switch user, and
    those are the buttons.

    This file is the left half and where the rest goes; the way in is
    SecureAuthCard with its two panels, the rail is SecureRail, and the log
    of this lock is SecureLog, which hears the authenticator for both.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

LockStyle {
    id: secure

    // The design's slate, cooler than the other dark styles.
    readonly property SecurePalette colours: SecurePalette {}

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: authCard.field
    promptBlock: authCard

    // --- the log of this lock ---------------------------------------------

    readonly property SecureLog log: SecureLog {
        ui: secure.ui
        colours: secure.colours
    }

    // --- the ground --------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: secure.colours.ground
    }

    // The accent's glow behind the left half, as the design's radial.
    Shape {
        width: secure.width - rail.width
        height: secure.height
        transform: Scale { origin.y: secure.height / 2; yScale: 0.84 }

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: secure.px(330)
                centerY: secure.height / 2
                centerRadius: secure.px(560)
                focalX: secure.px(330)
                focalY: secure.height / 2
                GradientStop { position: 0; color: Qt.alpha(secure.ui.accent, 0.14) }
                GradientStop { position: 1; color: Qt.alpha(secure.ui.accent, 0) }
            }
            startX: 0; startY: 0
            PathLine { x: secure.width - rail.width; y: 0 }
            PathLine { x: secure.width - rail.width; y: secure.height }
            PathLine { x: 0; y: secure.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // --- the header --------------------------------------------------------

    Row {
        x: secure.px(96)
        y: secure.px(64)
        spacing: secure.px(14)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: secure.px(28)
            height: width
            radius: secure.px(8)
            color: secure.ui.accent

            SymbolText {
                anchors.centerIn: parent
                symbol: "shield_lock"
                font.pixelSize: secure.px(17)
                color: "#ffffff"
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "SECURE WORKSTATION"
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: secure.px(14)
            font.weight: Font.Medium
            font.letterSpacing: 0.12 * secure.px(14)
            color: secure.colours.ink
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: chip.implicitWidth + secure.px(20)
            height: chip.implicitHeight + secure.px(8)
            radius: secure.px(6)
            color: "#1c2024"

            Text {
                id: chip
                anchors.centerIn: parent
                text: "session locked"
                textFormat: Text.PlainText
                font.family: "JetBrains Mono"
                font.pixelSize: secure.px(12)
                color: secure.colours.sub
            }
        }
    }

    // --- the clock ---------------------------------------------------------

    // Twenty-four hours with seconds, as the design draws it -- unless the
    // locale keeps twelve, which it is then drawn in.
    readonly property bool twelveHour: /a/i.test(Qt.locale().timeFormat(Locale.ShortFormat))

    Item {
        x: secure.px(96)
        y: secure.px(140)
        width: clock.width + seconds.implicitWidth
        height: secure.px(120) + dateLine.height
        opacity: secure.ui.showClock ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        // The design's line is exactly the type size; the font's own is
        // taller, so the digits are centred on the design's line.
        LockClock {
            id: clock

            y: -Math.round((clock.height - secure.px(104)) / 2)
            showDate: false
            raised: false
            family: "JetBrains Mono"
            timeWeight: Font.Medium
            timeSize: secure.px(104)
            format: secure.twelveHour ? "h:mm" : "HH:mm"
            ink: secure.colours.ink
        }

        FontMetrics { id: bigMetrics; font: clock.timeFont }
        FontMetrics { id: smallMetrics; font: seconds.font }

        Text {
            id: seconds

            x: clock.width
            y: clock.y + bigMetrics.ascent - smallMetrics.ascent
            text: Qt.formatTime(clock.now, secure.twelveHour ? ":ss AP" : ":ss")
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.weight: Font.Medium
            font.pixelSize: secure.px(40)
            font.features: { "tnum": 1 }
            color: secure.colours.faint
        }

        Text {
            id: dateLine

            y: secure.px(120)
            text: clock.now.toLocaleDateString(Qt.locale(), "ddd dd MMM yyyy").toUpperCase()
                + " · locked at " + Qt.formatTime(secure.ui.lockedAt, secure.twelveHour ? "h:mm AP" : "HH:mm")
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: secure.px(17)
            color: secure.colours.sub
        }
    }

    // --- the way in --------------------------------------------------------

    readonly property int leftWidth: Math.max(secure.px(420), Math.min(secure.px(880), secure.width - rail.width - secure.px(192)))

    SecureAuthCard {
        id: authCard

        x: secure.px(96)
        y: secure.px(340)
        width: secure.leftWidth
        ui: secure.ui
        colours: secure.colours
        unit: secure.unit
        faillock: secure.log.faillock
        twelveHour: secure.twelveHour
        opacity: secure.ui.unlock.shown ? 1 : 0
        enabled: secure.ui.unlock.shown

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
    }

    Text {
        x: secure.px(96)
        y: secure.px(360)
        opacity: secure.ui.unlock.shown ? 0 : 1
        text: "press a key or move the mouse to unlock"
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"
        font.pixelSize: secure.px(15)
        color: secure.colours.mut

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
    }

    // --- the foot ----------------------------------------------------------

    Item {
        x: secure.px(96)
        width: secure.leftWidth
        height: secure.px(44)
        y: secure.height - height - secure.px(64)
        opacity: secure.ui.unlock.shown ? 1 : 0
        enabled: secure.ui.unlock.shown

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        // Where the design has the help desk: the one other way in there is.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: secure.ui.keyboardAvailable
            spacing: secure.px(12)

            SymbolText {
                anchors.verticalCenter: parent.verticalCenter
                symbol: secure.ui.keyboardShown ? "keyboard_hide" : "keyboard"
                font.pixelSize: secure.px(22)
                color: oskHover.hovered ? secure.colours.ink : secure.colours.sub
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: secure.ui.keyboardShown ? "Hide on-screen keyboard" : "On-screen keyboard"
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: secure.px(14)
                color: oskHover.hovered ? secure.colours.ink : secure.colours.sub
            }

            HoverHandler { id: oskHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: secure.ui.toggleKeyboard()
            }
            Accessible.role: Accessible.Button
            Accessible.name: "On-screen keyboard"
        }

        LockActions {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            session: secure.ui.session
            shape: "square"
            unit: secure.unit
            size: secure.px(44)
            ink: "#c9ced4"
            fill: "#1a1d21"
            stroke: "transparent"
            hot: "#252a2f"
        }
    }

    // --- the rail ----------------------------------------------------------

    SecureRail {
        id: rail

        anchors.right: parent.right
        width: Math.max(secure.px(440), Math.min(secure.px(820), secure.width - secure.px(1100)))
        height: secure.height
        ui: secure.ui
        colours: secure.colours
        unit: secure.unit
        entries: secure.log.entries
    }
}
