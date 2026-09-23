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
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.battery
import org.kde.plasma.workspace.keyboardlayout as Layouts

LockStyle {
    id: secure

    readonly property real unit: secure.ui.unit

    // The design's slate, cooler than the other dark styles.
    readonly property color ground: "#0e1012"
    readonly property color railGround: "#121417"
    readonly property color card: "#15181b"
    readonly property color cardLine: "#262a2f"
    readonly property color well: "#1f2327"
    readonly property color ink: "#e9e5df"
    readonly property color sub: "#a9b0b8"
    readonly property color mut: "#8b939c"
    readonly property color faint: "#7d858e"
    readonly property color good: "#7fb98a"
    readonly property color bad: "#e0786a"
    readonly property color warn: "#e0c98a"

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: password
    promptBlock: authCard

    function px(n: real): int {
        return Math.round(n * secure.unit);
    }

    // --- what the greeter says it has --------------------------------------

    readonly property bool hasFingerprint: (secure.ui.unlock.alternatives & secure.ui.unlock.fingerprint) !== 0
    readonly property bool hasSmartcard: (secure.ui.unlock.alternatives & secure.ui.unlock.smartcard) !== 0
    readonly property bool hasAlternative: secure.hasFingerprint || secure.hasSmartcard

    // "key" or "password", as the tabs choose. The key comes first, as the
    // design has it, whenever there is one.
    property string chosen: "key"
    readonly property bool keyMode: secure.hasAlternative && secure.chosen === "key"
        && !secure.ui.unlock.unlockedWithoutPassword

    readonly property string keyTitle: secure.hasSmartcard && secure.hasFingerprint ? "Key or fingerprint"
        : secure.hasSmartcard ? "Security key" : "Fingerprint"
    readonly property string keyGlyph: secure.hasSmartcard ? "usb" : "fingerprint"
    readonly property string keyAsk: secure.hasSmartcard && secure.hasFingerprint
        ? "Use your security key, or touch the fingerprint sensor"
        : secure.hasSmartcard ? "Insert or touch your security key" : "Touch the fingerprint sensor"

    // --- the log of this lock ---------------------------------------------

    property int refused: 0
    // Set once pam_faillock has said something: only then is it known to be
    // counting this account's failures.
    property bool faillock: false
    property var seenLines: []

    ListModel {
        id: log
    }

    function stamp(d: date): string {
        return Qt.formatTime(d, "HH:mm:ss");
    }

    function addLog(what: string, how: string, tint: color): void {
        log.insert(0, { "t": secure.stamp(new Date()), "what": what, "how": how, "tint": String(tint) });
        while (log.count > 6)
            log.remove(log.count - 1);
    }

    Component.onCompleted: {
        log.append({ "t": secure.stamp(secure.ui.lockedAt), "what": "Locked", "how": "this greeter started", "tint": String(secure.mut) });
    }

    Connections {
        target: secure.ui.unlock

        function onRejected() {
            secure.refused += 1;
            secure.addLog("Password refused", `attempt ${secure.refused} this lock`, secure.bad);
        }

        // Each new line PAM says, once. "Unlocking failed" is our own word
        // for a refusal, which is logged above rather than twice.
        function onMessageChanged() {
            const lines = secure.ui.unlock.message ? secure.ui.unlock.message.split("\n") : [];
            for (const line of lines) {
                if (!line || secure.seenLines.includes(line) || line === "Unlocking failed")
                    continue;
                const lockout = secure.ui.unlock.lockoutIn(line) > 0;
                if (lockout || /faillock/i.test(line))
                    secure.faillock = true;
                secure.addLog(line, lockout ? "pam_faillock" : "PAM", lockout ? secure.bad : secure.mut);
            }
            secure.seenLines = lines;
        }

        function onUnlockedWithoutPasswordChanged() {
            if (secure.ui.unlock.unlockedWithoutPassword)
                secure.addLog("Accepted without a password", "confirm to unlock", secure.good);
        }

        function onShownChanged() {
            if (!secure.ui.unlock.shown && password.text.length === 0)
                secure.chosen = "key";
        }
    }

    // --- the machine -------------------------------------------------------

    BatteryControlModel {
        id: battery
    }

    Layouts.KeyboardLayout {
        id: layouts
    }

    readonly property string layoutName: layouts.layoutsList.length > 0
        ? (layouts.layoutsList[layouts.layout]?.longName ?? "") : ""

    readonly property string batteryGlyph: battery.pluggedIn ? "battery_charging_full"
        : battery.percent >= 95 ? "battery_full"
        : "battery_" + Math.max(0, Math.min(6, Math.floor(battery.percent / 15))) + "_bar"

    function duration(ms: real): string {
        const m = Math.round(ms / 60000);
        if (m < 60)
            return `${m} min`;
        const h = Math.floor(m / 60), r = m % 60;
        return r ? `${h} h ${r} min` : `${h} h`;
    }

    // --- the ground --------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: secure.ground
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

            Text {
                anchors.centerIn: parent
                text: "shield_lock"
                font.family: "Material Symbols Rounded"
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
            color: secure.ink
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
                color: secure.sub
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
            ink: secure.ink
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
            color: secure.faint
        }

        Text {
            id: dateLine

            y: secure.px(120)
            text: clock.now.toLocaleDateString(Qt.locale(), "ddd dd MMM yyyy").toUpperCase()
                + " · locked at " + Qt.formatTime(secure.ui.lockedAt, secure.twelveHour ? "h:mm AP" : "HH:mm")
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: secure.px(17)
            color: secure.sub
        }
    }

    // --- the way in --------------------------------------------------------

    readonly property int leftWidth: Math.max(secure.px(420), Math.min(secure.px(880), secure.width - rail.width - secure.px(192)))

    component Tab: Rectangle {
        id: tab

        property string glyph: ""
        property string label: ""
        property bool active: false
        signal chosen

        width: tabRow.implicitWidth + secure.px(36)
        height: secure.px(40)
        radius: secure.px(10)
        color: tab.active ? "#2a2f36" : (tabHover.hovered ? "#161a1e" : "transparent")

        Row {
            id: tabRow
            anchors.centerIn: parent
            spacing: secure.px(8)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tab.glyph
                font.family: "Material Symbols Rounded"
                font.pixelSize: secure.px(18)
                color: tab.active ? "#ffffff" : secure.sub
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tab.label
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: secure.px(14)
                font.weight: Font.Medium
                color: tab.active ? "#ffffff" : secure.sub
            }
        }

        HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tab.chosen() }
        Accessible.role: Accessible.PageTab
        Accessible.name: tab.label
    }

    Rectangle {
        id: authCard

        x: secure.px(96)
        y: secure.px(340)
        width: secure.leftWidth
        height: cardBody.height + secure.px(68)
        radius: secure.px(24)
        color: secure.card
        border.width: 1
        border.color: secure.cardLine
        opacity: secure.ui.unlock.shown ? 1 : 0
        enabled: secure.ui.unlock.shown

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        Column {
            id: cardBody

            x: secure.px(40)
            y: secure.px(32)
            width: parent.width - 2 * x
            spacing: secure.px(34)

            // Only when there is something besides the password to choose.
            Rectangle {
                visible: secure.hasAlternative && !secure.ui.unlock.unlockedWithoutPassword
                width: tabs.implicitWidth + secure.px(10)
                height: tabs.implicitHeight + secure.px(10)
                radius: secure.px(14)
                color: secure.ground

                Row {
                    id: tabs
                    anchors.centerIn: parent
                    spacing: secure.px(6)

                    Tab {
                        glyph: secure.hasSmartcard ? "key" : "fingerprint"
                        label: secure.keyTitle
                        active: secure.keyMode
                        onChosen: {
                            secure.chosen = "key";
                            secure.ui.focusPassword();
                        }
                    }

                    Tab {
                        glyph: "password"
                        label: "Password"
                        active: !secure.keyMode
                        onChosen: {
                            secure.chosen = "password";
                            secure.ui.focusPassword();
                        }
                    }
                }
            }

            // The key panel sits over the password one rather than replacing
            // it, so the field keeps the keyboard: the first key typed is the
            // first character of the password, and switches to it.
            Item {
                width: parent.width
                height: secure.keyMode ? keyPanel.height : pwPanel.height

                Column {
                    id: pwPanel

                    width: parent.width
                    spacing: 0
                    opacity: secure.keyMode ? 0 : 1

                    Row {
                        spacing: secure.px(16)

                        LockFace {
                            width: secure.px(52)
                            height: width
                            image: secure.ui.userImage
                            userName: secure.ui.userName
                            ink: "#3d3a35"
                            fill: "#c9c4d8"
                            ring: "transparent"
                            ringWidth: 0
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: secure.ui.userName
                            textFormat: Text.PlainText
                            font.family: "Rubik"
                            font.pixelSize: secure.px(18)
                            font.weight: Font.Medium
                            color: secure.ink
                        }
                    }

                    Item { width: 1; height: secure.px(24) }

                    LockPrompt {
                        id: password

                        width: parent.width
                        height: secure.px(60)
                        unlock: secure.ui.unlock
                        unit: secure.unit
                        radius: secure.px(14)
                        glyph: "password"
                        ink: secure.ink
                        dim: secure.sub
                        accent: secure.ui.accent
                        fieldColor: secure.ground
                        fieldBorder: secure.ui.unlock.resting ? secure.bad
                            : password.field.activeFocus && !secure.keyMode ? secure.ui.accent
                            : Qt.rgba(0.5, 0.5, 0.5, 0.32)

                        onTextChanged: {
                            if (password.text.length > 0)
                                secure.chosen = "password";
                        }
                    }

                    Item { width: 1; height: secure.px(12) }

                    LockMessage {
                        width: parent.width
                        unlock: secure.ui.unlock
                        unit: secure.unit
                        align: Text.AlignLeft
                        ink: secure.sub
                        warn: secure.warn
                    }

                    Text {
                        readonly property var parts: [
                            secure.refused > 0
                                ? `${secure.refused} refused since ${Qt.formatTime(secure.ui.lockedAt, secure.twelveHour ? "h:mm AP" : "HH:mm")}`
                                : "enter ⏎ to unlock",
                            secure.faillock ? "failures on this account are counted by pam_faillock" : "",
                        ].filter(p => p)

                        topPadding: secure.px(8)
                        width: parent.width
                        text: parts.join(" · ")
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        font.family: "JetBrains Mono"
                        font.pixelSize: secure.px(13)
                        color: secure.mut
                    }
                }

                // Insert, touch, PIN: PAM's steps, said in PAM's words.
                Item {
                    id: keyPanel

                    visible: secure.keyMode
                    width: parent.width
                    height: Math.max(ring.height, keyText.height)

                    // Clicks here are not for the field hidden underneath.
                    MouseArea {
                        anchors.fill: parent
                        onPressed: secure.ui.focusPassword()
                    }

                    Item {
                        id: ring

                        width: secure.px(148)
                        height: width
                        anchors.verticalCenter: parent.verticalCenter

                        Shape {
                            anchors.fill: parent

                            ShapePath {
                                strokeColor: "#3d434a"
                                strokeWidth: Math.max(1, secure.px(2))
                                strokeStyle: ShapePath.DashLine
                                dashPattern: [3, 2.4]
                                fillColor: "transparent"

                                PathAngleArc {
                                    centerX: ring.width / 2
                                    centerY: ring.height / 2
                                    radiusX: ring.width / 2 - secure.px(1)
                                    radiusY: ring.height / 2 - secure.px(1)
                                    startAngle: 0
                                    sweepAngle: 360
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: secure.keyGlyph
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: secure.px(58)
                            color: "#c9ced4"
                        }
                    }

                    Column {
                        id: keyText

                        anchors.left: ring.right
                        anchors.leftMargin: secure.px(36)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: secure.px(8)

                        Text {
                            width: parent.width
                            text: secure.keyAsk
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            font.family: "Rubik"
                            font.pixelSize: secure.px(30)
                            color: secure.ink
                        }

                        Text {
                            width: parent.width
                            text: secure.ui.unlock.message
                                || "PAM is waiting for it alongside the password. What it says will appear here."
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            lineHeight: 1.3
                            font.family: "Rubik"
                            font.pixelSize: secure.px(16)
                            color: secure.ui.unlock.message ? secure.ink : secure.sub
                        }

                        Item { width: 1; height: secure.px(14) }

                        Rectangle {
                            width: useText.implicitWidth + secure.px(44)
                            height: secure.px(46)
                            radius: secure.px(12)
                            color: useHover.hovered ? "#2a2f36" : secure.well

                            Text {
                                id: useText
                                anchors.centerIn: parent
                                text: "Use password instead"
                                textFormat: Text.PlainText
                                font.family: "Rubik"
                                font.pixelSize: secure.px(15)
                                font.weight: Font.Medium
                                color: secure.ink
                            }

                            HoverHandler { id: useHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    secure.chosen = "password";
                                    secure.ui.focusPassword();
                                }
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: "Use password instead"
                        }
                    }
                }
            }
        }
    }

    Text {
        x: secure.px(96)
        y: secure.px(360)
        opacity: secure.ui.unlock.shown ? 0 : 1
        text: "press a key or move the mouse to unlock"
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"
        font.pixelSize: secure.px(15)
        color: secure.mut

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
            visible: secure.ui.keyboard?.status === Loader.Ready
            spacing: secure.px(12)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: secure.ui.keyboard?.keyboardActive ? "keyboard_hide" : "keyboard"
                font.family: "Material Symbols Rounded"
                font.pixelSize: secure.px(22)
                color: oskHover.hovered ? secure.ink : secure.sub
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: secure.ui.keyboard?.keyboardActive ? "Hide on-screen keyboard" : "On-screen keyboard"
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: secure.px(14)
                color: oskHover.hovered ? secure.ink : secure.sub
            }

            HoverHandler { id: oskHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    secure.ui.focusPassword();
                    secure.ui.keyboard.showHide();
                }
            }
            Accessible.role: Accessible.Button
            Accessible.name: "On-screen keyboard"
        }

        LockActions {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Options.showSessionButtons
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

    component Heading: Item {
        id: heading

        property string label: ""
        property string aside: ""
        property color asideColor: secure.sub

        width: parent?.width ?? 0
        height: headingText.implicitHeight

        Text {
            id: headingText
            text: heading.label
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: secure.px(12)
            font.letterSpacing: 0.14 * secure.px(12)
            color: secure.mut
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: heading.aside
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: secure.px(13)
            color: heading.asideColor
        }
    }

    component Way: Item {
        id: way

        property string glyph: ""
        property string label: ""
        property bool offered: false

        width: parent?.width ?? 0
        height: secure.px(44)

        Text {
            id: wayGlyph
            anchors.verticalCenter: parent.verticalCenter
            text: way.offered ? "check_circle" : "do_not_disturb_on"
            font.family: "Material Symbols Rounded"
            font.pixelSize: secure.px(20)
            color: way.offered ? secure.good : "#5d646c"
        }

        Text {
            anchors.left: wayGlyph.right
            anchors.leftMargin: secure.px(12)
            anchors.verticalCenter: parent.verticalCenter
            text: way.label
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: secure.px(15)
            color: way.offered ? secure.ink : secure.mut
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: way.glyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: secure.px(18)
            color: secure.faint
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#1d2126"
        }
    }

    component Tile: Rectangle {
        id: tile

        property string glyph: ""
        property string label: ""
        property string detail: ""
        property color tint: secure.ink

        height: tileBody.implicitHeight + secure.px(28)
        radius: secure.px(14)
        color: "#181b1f"

        Column {
            id: tileBody

            x: secure.px(16)
            y: secure.px(14)
            width: parent.width - 2 * x
            spacing: secure.px(6)

            Row {
                spacing: secure.px(8)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.glyph
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: secure.px(18)
                    color: tile.tint
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.label
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: secure.px(14)
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
                font.pixelSize: secure.px(12.5)
                color: secure.sub
            }
        }
    }

    Rectangle {
        id: rail

        anchors.right: parent.right
        width: Math.max(secure.px(440), Math.min(secure.px(820), secure.width - secure.px(1100)))
        height: secure.height
        color: secure.railGround

        Rectangle {
            width: 1
            height: parent.height
            color: "#20242a"
        }

        Column {
            x: secure.px(64)
            y: secure.px(60)
            width: parent.width - 2 * x
            spacing: secure.px(30)

            // Where the design has device posture: the ways in, which the
            // greeter does know.
            Column {
                width: parent.width
                spacing: secure.px(12)

                Heading {
                    label: "AUTHENTICATION"
                    aside: "offered by PAM here"
                }

                Column {
                    width: parent.width

                    Way {
                        label: "Password"
                        glyph: "password"
                        offered: true
                    }

                    Way {
                        label: "Security key or smartcard"
                        glyph: "usb"
                        offered: secure.hasSmartcard
                    }

                    Way {
                        label: "Fingerprint"
                        glyph: "fingerprint"
                        offered: secure.hasFingerprint
                    }
                }
            }

            // Where the design has journald: this lock, as this greeter saw it.
            Column {
                width: parent.width
                spacing: secure.px(12)

                Heading {
                    label: "THIS LOCK"
                    aside: "since this lock · this greeter"
                }

                Column {
                    width: parent.width

                    Repeater {
                        model: log

                        Item {
                            id: entry

                            required property string t
                            required property string what
                            required property string how
                            required property string tint

                            width: parent.width
                            height: secure.px(38)

                            Rectangle {
                                id: dot
                                anchors.verticalCenter: parent.verticalCenter
                                width: secure.px(8)
                                height: width
                                radius: width / 2
                                color: entry.tint
                            }

                            Text {
                                id: when
                                anchors.left: dot.right
                                anchors.leftMargin: secure.px(14)
                                anchors.verticalCenter: parent.verticalCenter
                                width: secure.px(72)
                                text: entry.t
                                textFormat: Text.PlainText
                                font.family: "JetBrains Mono"
                                font.pixelSize: secure.px(13)
                                color: secure.sub
                            }

                            Text {
                                anchors.left: when.right
                                anchors.leftMargin: secure.px(10)
                                anchors.right: how.left
                                anchors.rightMargin: secure.px(14)
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.what
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                font.family: "Rubik"
                                font.pixelSize: secure.px(15)
                                color: secure.ink
                            }

                            Text {
                                id: how
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.how
                                textFormat: Text.PlainText
                                font.family: "Rubik"
                                font.pixelSize: secure.px(13)
                                color: secure.sub
                            }
                        }
                    }
                }
            }

            // Where the design has VPN and Wi-Fi: the two things about this
            // machine the greeter can read.
            Row {
                width: parent.width
                spacing: secure.px(12)
                visible: layoutTile.visible || batteryTile.visible

                readonly property int tiles: (layoutTile.visible ? 1 : 0) + (batteryTile.visible ? 1 : 0)
                readonly property real tileWidth: (width - (tiles - 1) * spacing) / Math.max(1, tiles)

                Tile {
                    id: layoutTile

                    visible: secure.layoutName !== ""
                    width: parent.tileWidth
                    glyph: "keyboard"
                    label: layouts.layoutsList.length > 1 ? "Layout · tap to switch" : "Keyboard layout"
                    detail: secure.layoutName
                    tint: layouts.layout > 0 ? secure.warn : secure.ink

                    HoverHandler {
                        enabled: layouts.layoutsList.length > 1
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        enabled: layouts.layoutsList.length > 1 && secure.ui.unlock.shown
                        onTapped: {
                            layouts.switchToNextLayout();
                            secure.ui.focusPassword();
                        }
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: "Keyboard layout: " + secure.layoutName
                }

                Tile {
                    id: batteryTile

                    visible: battery.hasInternalBatteries
                    width: parent.tileWidth
                    glyph: secure.batteryGlyph
                    label: `Battery · ${battery.percent}%`
                    tint: battery.pluggedIn ? secure.good : secure.ink
                    detail: battery.pluggedIn ? "plugged in"
                        : battery.remainingMsec > 0 ? `on battery · ${secure.duration(battery.remainingMsec)} left`
                        : "on battery"
                }
            }
        }

        // The design's "managed by IT" line, said of what this screen is.
        Row {
            x: secure.px(64)
            width: parent.width - 2 * x
            y: parent.height - height - secure.px(60)
            spacing: secure.px(12)

            Text {
                id: policyGlyph
                text: "policy"
                font.family: "Material Symbols Rounded"
                font.pixelSize: secure.px(18)
                color: secure.mut
            }

            Text {
                width: parent.width - policyGlyph.width - parent.spacing
                text: "This list is kept by the lock screen for this lock only and ends with it. "
                    + "Nothing here is written anywhere; PAM decides what is allowed and when."
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                lineHeight: 1.3
                font.family: "Rubik"
                font.pixelSize: secure.px(13)
                color: secure.mut
            }
        }
    }
}
