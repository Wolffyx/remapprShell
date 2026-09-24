/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Accessible (3c) -- large type, high contrast and the on-screen keyboard
    as first-class controls along the top, not buried in a menu, and a
    caption strip along the foot that says what the screen is announcing.

    It opens as the design does: text at 120% and the high-contrast palette,
    black and white with the design's yellow for the accent -- in high
    contrast the accent is that yellow, not the accent setting, because the
    yellow is what the contrast is for. Standard contrast is the design's
    other palette, with the accent setting lightened halfway to white in
    place of its #9fb0ee (which is indigo lightened the same way), so the
    dark type the design puts on it stays readable whichever accent is set.

    Every choice along the top lasts for this lock only. The greeter runs
    sandboxed and cannot write a file, so there is nowhere to keep a text
    size for next time; the next lock opens at the design's defaults again.

    What the design draws and this does not:

    - "Screen reader: On". The greeter cannot start Orca -- it cannot run a
      process -- so a switch for it would be a picture of one. The design's
      caption strip is kept, relabelled for what it is: *this screen's* own
      announcements, written by this file (the characters typed so far, what
      PAM said, Caps Lock, a refusal). It is not Orca's output, which nothing
      here can read. The same sentences go to `Accessible.announce`, and
      every control carries a name and a description, so a screen reader
      that is running on the greeter's accessibility bridge says the same.
    - The design's own keyboard. The toggle shows and hides Plasma's, the one
      the frame owns, and is not drawn at all where that one did not load.
      It starts hidden: shown, it keeps the prompt up for good.
    - Two of the four cards under the clock (the weather, the next event)
      and the notification count, which the greeter cannot know. The cards
      that are drawn are true ones: the battery, when the lock started, the
      keyboard layout when there is more than one, and what is playing.
    - The "Show" button beside the password. Plasma's field has its own
      reveal button, and the caption says when the password is shown.
    - The demo password under the field; in its place, what to do next.
    - "3 attempts left". PAM does not say how many are left until it says
      there are none, and that countdown is the frame's.

    Reduce motion stops the digits rolling, the fades, and (through
    `reduceMotion`) the shutter.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.mpris as Mpris

LockStyle {
    id: access

    // --- this lock's choices ---------------------------------------------

    // The text size, as the design offers it; everything but the page's own
    // margins is drawn at `s`.
    property real size: 1.2
    property string contrast: "high"
    property bool captions: true

    readonly property real s: access.unit * access.size

    // The design's two palettes.
    readonly property bool high: access.contrast === "high"
    readonly property color bg: access.high ? "#000000" : "#1c1a17"
    readonly property color fg: access.high ? "#ffffff" : "#f4efe8"
    readonly property color sub: access.high ? "#e6e6e6" : "#cfc7bd"
    readonly property color acc: access.high ? "#ffd84a" : Qt.tint(access.ui.accent, Qt.rgba(1, 1, 1, 0.5))
    readonly property color bd: access.high ? "#ffffff" : Qt.rgba(1, 1, 1, 0.34)
    readonly property color bdSoft: access.high ? "#8a8a8a" : Qt.rgba(1, 1, 1, 0.14)
    readonly property color card: access.high ? "#121212" : "#27241f"
    readonly property color accentFg: access.high ? "#000000" : "#14161f"
    readonly property color err: access.high ? "#ff7a6b" : "#e0786a"
    readonly property color warn: access.high ? "#ffd84a" : "#e0c98a"
    readonly property color hot: access.high ? "#262626" : "#332f29"

    // The borders the design draws at 2 and 3 px, and the focus ring.
    readonly property int line: Math.max(2, Math.round(2 * access.s))
    readonly property int thick: Math.max(3, Math.round(3 * access.s))
    readonly property int ringGap: Math.max(3, Math.round(4 * access.s))

    readonly property int margin: Math.round(80 * access.unit)
    readonly property int fade: access.reduceMotion ? 0 : 250

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: password
    promptBlock: unlockButton

    // The lockout countdown goes just above the caption strip, where there
    // is nothing, rather than over the bar of choices at the top.
    toastY: strip.y - Math.round((72 + 24) * access.unit)

    // --- the caption -------------------------------------------------------

    // What this screen would say, said: on the strip at the foot while
    // captions are on, and to a screen reader when one is listening.
    // `spoken` is false for the running count of characters, which a screen
    // reader already echoes as they are typed.
    property string caption: ""

    function say(text: string, spoken: bool): void {
        access.caption = text;
        if (spoken)
            access.Accessible.announce(text);
    }

    function count(n: int): string {
        return n + (n === 1 ? " character" : " characters");
    }

    readonly property string intro: "Lock screen. Password field."
        + (access.ui.unlock.hasFingerprint ? " Or touch the fingerprint sensor." : "")
        + " Accessibility options are above."

    Component.onCompleted: access.say(access.ui.unlock.shown ? access.intro
        : "Locked. Start typing your password, or move the mouse.", true)

    Connections {
        target: LockKeys.capsLock
        function onLockedChanged() {
            access.say(LockKeys.capsLock.locked ? "Caps Lock is on." : "Caps Lock is off.", true);
        }
    }

    Connections {
        target: LockKeys.keyboardLayout
        function onLayoutChanged() {
            const layout = LockKeys.keyboardLayout;
            const name = layout.layoutsList[layout.layout]?.longName ?? "";
            if (name)
                access.say("Keyboard layout: " + name + ".", true);
        }
    }

    readonly property LockPower battery: access.ui.battery

    // The characters typed so far, and why the count went down.
    property int typed: 0

    Connections {
        target: password
        function onTextChanged() {
            const n = password.text.length;
            if (n > access.typed)
                access.say("Password field. " + access.count(n) + " entered.", false);
            else if (n === 0 && access.typed > 1)
                access.say("Password cleared.", true);
            else if (n < access.typed)
                access.say("Deleted. " + access.count(n) + ".", false);
            access.typed = n;
        }
    }

    Connections {
        target: password.field
        function onShowPasswordChanged() {
            access.say(password.field.showPassword ? "Password shown." : "Password hidden.", true);
        }
    }

    Connections {
        target: access.ui.unlock
        function onShownChanged() {
            access.say(access.ui.unlock.shown ? access.intro
                : "Locked. Start typing your password, or move the mouse.", true);
        }
        function onMessageChanged() {
            const last = access.ui.unlock.message.split("\n").pop();
            // A refusal is said by onRejected, with what to do about it.
            if (last && last !== "Unlocking failed")
                access.say(last.endsWith(".") ? last : last + ".", true);
        }
        function onRejected() {
            access.say("Unlocking failed. The password was not accepted. Wait a moment, then try again.", true);
        }
        function onRestingChanged() {
            if (!access.ui.unlock.resting && access.ui.unlock.shown)
                access.say("Password field is ready again.", true);
        }
        function onLockedUntilChanged() {
            const left = access.ui.unlock.lockedUntil - Date.now();
            if (left > 0) {
                const m = Math.ceil(left / 60000);
                access.say("Too many attempts. Input is paused for " + m + (m === 1 ? " minute." : " minutes."), true);
            }
        }
        function onUnlockedWithoutPasswordChanged() {
            if (access.ui.unlock.unlockedWithoutPassword)
                access.say("No password needed. Press Unlock to continue.", true);
        }
    }

    // --- the parts ---------------------------------------------------------

    // A ring outside whatever has the keyboard focus, clear of it by a gap
    // so that it shows around a filled button as well as an empty one.
    component Ring: Rectangle {
        required property Rectangle target

        anchors.fill: parent
        anchors.margins: -(access.ringGap + access.thick)
        visible: target.activeFocus
        radius: target.radius + access.ringGap + access.thick
        color: "transparent"
        border.width: access.thick
        border.color: access.acc
    }

    // A segment of the text size and contrast choices, or one of the
    // switches: a bordered box, filled with the accent while it is on.
    component Choice: Rectangle {
        id: choice

        property string label: ""
        property string glyph: ""
        property bool on: false
        property bool isSwitch: false
        property string description: ""
        signal activated

        function activate(): void {
            choice.activated();
        }

        width: choiceRow.implicitWidth + 2 * Math.round(18 * access.s)
        height: Math.round(52 * access.s)
        radius: Math.round(12 * access.s)
        color: choice.on ? access.acc : (choiceHover.hovered ? access.hot : "transparent")
        border.width: access.line
        border.color: access.bd
        activeFocusOnTab: true

        Row {
            id: choiceRow

            anchors.centerIn: parent
            spacing: Math.round(10 * access.s)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: choice.glyph !== ""
                text: choice.glyph
                font.family: "Material Symbols Rounded"
                font.pixelSize: Math.round(24 * access.s)
                color: choice.on ? access.accentFg : access.fg
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: choice.isSwitch ? `${choice.label}: ${choice.on ? "On" : "Off"}` : choice.label
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: Math.round(18 * access.s)
                font.weight: Font.Medium
                color: choice.on ? access.accentFg : access.fg
            }
        }

        Ring { target: choice }

        HoverHandler { id: choiceHover; cursorShape: Qt.PointingHandCursor }
        // A click leaves the keyboard in the password field; a key press on
        // a focused switch leaves it on the switch, where Tab put it.
        TapHandler {
            onTapped: {
                choice.activate();
                access.ui.focusPassword();
            }
        }
        Keys.onSpacePressed: choice.activate()
        Keys.onReturnPressed: choice.activate()
        Keys.onEnterPressed: choice.activate()

        Accessible.role: choice.isSwitch ? Accessible.CheckBox : Accessible.RadioButton
        Accessible.name: choice.label
        Accessible.description: choice.description
        Accessible.checkable: true
        Accessible.checked: choice.on
        Accessible.focusable: true
        Accessible.onPressAction: choice.activate()
        Accessible.onToggleAction: choice.activate()
    }

    // One of the cards under the clock: a glyph in the accent and a line
    // of large type.
    component Fact: Rectangle {
        id: fact

        property string glyph: ""
        property string text: ""
        property string description: ""
        // The layout card switches to the next layout.
        property bool pressable: false
        signal activated

        width: parent?.width ?? 0
        height: factText.implicitHeight + 2 * Math.round(18 * access.s)
        radius: Math.round(18 * access.s)
        color: fact.pressable && factHover.hovered ? access.hot : access.card
        border.width: access.line
        border.color: access.bdSoft
        activeFocusOnTab: fact.pressable

        Text {
            id: factGlyph

            x: Math.round(22 * access.s)
            anchors.verticalCenter: parent.verticalCenter
            text: fact.glyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: Math.round(34 * access.s)
            color: access.acc
        }

        Text {
            id: factText

            anchors.left: factGlyph.right
            anchors.leftMargin: Math.round(18 * access.s)
            anchors.right: parent.right
            anchors.rightMargin: Math.round(22 * access.s)
            anchors.verticalCenter: parent.verticalCenter
            text: fact.text
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            lineHeight: 1.2
            font.family: "Rubik"
            font.pixelSize: Math.round(22 * access.s)
            color: access.fg
        }

        Ring { target: fact }

        HoverHandler {
            id: factHover
            enabled: fact.pressable
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            enabled: fact.pressable
            onTapped: {
                fact.activated();
                access.ui.focusPassword();
            }
        }
        Keys.onSpacePressed: if (fact.pressable) fact.activated()
        Keys.onReturnPressed: if (fact.pressable) fact.activated()
        Keys.onEnterPressed: if (fact.pressable) fact.activated()

        Accessible.role: fact.pressable ? Accessible.Button : Accessible.StaticText
        Accessible.name: fact.text
        Accessible.description: fact.description
        Accessible.onPressAction: if (fact.pressable) fact.activated()
    }

    // --- the page ----------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: access.bg
    }

    // --- the choices -------------------------------------------------------

    Flow {
        id: choices

        x: access.margin
        y: Math.round(64 * access.unit)
        width: access.width - 2 * access.margin
        spacing: Math.round(28 * access.s)
        opacity: access.ui.unlock.shown ? 1 : 0
        enabled: access.ui.unlock.shown

        Behavior on opacity { NumberAnimation { duration: access.fade } }

        Row {
            spacing: Math.round(10 * access.s)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Text size"
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: Math.round(17 * access.s)
                font.weight: Font.Medium
                color: access.sub
                Accessible.ignored: true
            }

            Repeater {
                model: [[1, "100%"], [1.2, "120%"], [1.4, "140%"]]

                Choice {
                    required property var modelData
                    label: modelData[1]
                    on: Math.abs(access.size - modelData[0]) < 0.01
                    description: "Text size. Lasts for this lock only."
                    onActivated: {
                        access.size = modelData[0];
                        access.say(`Text size ${modelData[1]}.`, true);
                    }
                }
            }
        }

        Row {
            spacing: Math.round(10 * access.s)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Contrast"
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: Math.round(17 * access.s)
                font.weight: Font.Medium
                color: access.sub
                Accessible.ignored: true
            }

            Repeater {
                model: [["standard", "Standard"], ["high", "High"]]

                Choice {
                    required property var modelData
                    label: modelData[1]
                    on: access.contrast === modelData[0]
                    description: "Contrast. Lasts for this lock only."
                    onActivated: {
                        access.contrast = modelData[0];
                        access.say(`${modelData[1]} contrast.`, true);
                    }
                }
            }
        }

        Row {
            spacing: Math.round(10 * access.s)

            Choice {
                isSwitch: true
                glyph: "closed_caption"
                label: "Captions"
                on: access.captions
                description: "Shows what this screen announces, along the bottom. Lasts for this lock only."
                onActivated: {
                    access.captions = !access.captions;
                    access.say(access.captions ? "Captions on." : "Captions off.", true);
                }
            }

            Choice {
                isSwitch: true
                visible: access.ui.keyboard?.status === Loader.Ready
                glyph: "keyboard"
                label: "Keyboard"
                on: access.ui.keyboard?.keyboardActive ?? false
                description: "Shows or hides the on-screen keyboard."
                onActivated: {
                    const showing = !(access.ui.keyboard?.keyboardActive ?? false);
                    access.ui.focusPassword();
                    access.ui.keyboard.showHide();
                    access.say(showing ? "On-screen keyboard shown." : "On-screen keyboard hidden.", true);
                }
            }

            Choice {
                isSwitch: true
                glyph: "animation"
                label: "Reduce motion"
                on: access.reduceMotion
                description: "Stops the clock rolling and the fades. Lasts for this lock only."
                onActivated: {
                    access.reduceMotion = !access.reduceMotion;
                    access.say(access.reduceMotion ? "Reduce motion on." : "Reduce motion off.", true);
                }
            }
        }
    }

    // --- the time, and what is true of the machine ---------------------------

    // The design's 72 px under the choices, given up (down to 24) when the
    // choices wrap onto a second line at 140% and the prompt would otherwise
    // run into the caption strip.
    readonly property int colTop: {
        const below = choices.y + choices.height;
        const floor = access.height - (strip.visible ? strip.height : 0) - Math.round(24 * access.unit);
        const room = floor - right.height - below;
        return below + Math.max(Math.round(24 * access.unit), Math.min(Math.round(72 * access.unit), room));
    }
    readonly property int rightX: Math.round(access.width * 1020 / 1920)

    Column {
        x: access.margin
        y: access.colTop
        width: access.rightX - access.margin - Math.round(80 * access.unit)
        spacing: 0

        LockClock {
            id: clock

            opacity: access.ui.showClock ? 1 : 0
            raised: false
            animated: !access.reduceMotion
            ink: access.fg
            dateInk: access.sub
            timeSize: Math.round(130 * access.s)
            dateSize: Math.round(28 * access.s)
            timeWeight: Font.Light
            Accessible.role: Accessible.StaticText
            Accessible.name: `${clock.timeText}, ${clock.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)}`

            Behavior on opacity { NumberAnimation { duration: access.fade } }
        }

        Item {
            width: 1
            height: Math.round(40 * access.s)
        }

        Column {
            width: parent.width
            spacing: Math.round(14 * access.s)

            Fact {
                visible: access.battery.present
                glyph: access.battery.plugged ? "battery_charging_full" : "battery_5_bar"
                text: {
                    const b = access.battery;
                    const left = b.smoothedRemainingMsec > 0 ? LockText.duration(b.smoothedRemainingMsec, true) : "";
                    if (b.plugged && b.percent < 100)
                        return `Battery ${b.percent}%, charging` + (left ? ` · full in ${left}` : "");
                    if (b.plugged)
                        return `Battery ${b.percent}%, plugged in`;
                    return `Battery ${b.percent}%` + (left ? ` · about ${left} left` : "");
                }
            }

            Fact {
                glyph: "lock_clock"
                text: "Locked at " + access.ui.lockedAt.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
            }

            Fact {
                visible: LockKeys.layouts.length > 1
                pressable: true
                glyph: "keyboard"
                text: "Keyboard layout: " + LockKeys.layoutName
                description: "Switches to the next keyboard layout."
                onActivated: LockKeys.nextLayout()
            }

            Repeater {
                model: LockKeys.players

                Fact {
                    required property var model
                    visible: access.ui.setting("showMediaControls", true) && model.track.length > 0
                    glyph: model.playbackStatus === Mpris.PlaybackStatus.Playing ? "graphic_eq" : "music_note"
                    text: (model.playbackStatus === Mpris.PlaybackStatus.Playing ? "Playing " : "Paused: ")
                        + model.track + (model.artist ? ` · ${model.artist}` : "")
                }
            }
        }
    }

    // --- the prompt ----------------------------------------------------------

    Column {
        id: right

        x: access.rightX
        y: access.colTop
        width: access.width - access.rightX - access.margin
        spacing: 0
        opacity: access.ui.unlock.shown ? 1 : 0
        enabled: access.ui.unlock.shown

        Behavior on opacity { NumberAnimation { duration: access.fade } }

        Text {
            text: "Unlock this computer"
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: Math.round(34 * access.s)
            font.weight: Font.Medium
            color: access.fg
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }

        Item { width: 1; height: Math.round(20 * access.s) }

        Row {
            spacing: Math.round(16 * access.s)

            LockFace {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(60 * access.s)
                height: width
                image: access.ui.userImage
                userName: access.ui.userName
                ink: access.fg
                fill: access.card
                ring: access.bd
                ringWidth: access.line
                Accessible.ignored: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: access.ui.userName
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: Math.round(22 * access.s)
                font.weight: Font.Medium
                color: access.fg
                Accessible.role: Accessible.StaticText
                Accessible.name: "Account: " + access.ui.userName
            }
        }

        Item { width: 1; height: Math.round(22 * access.s) }

        Text {
            text: "Password"
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: Math.round(22 * access.s)
            color: access.sub
            Accessible.ignored: true
        }

        Item { width: 1; height: Math.round(10 * access.s) }

        // The field's box: the design's thick border, in the accent while
        // the field has the keyboard and in the error colour after a refusal.
        Rectangle {
            id: fieldBox

            width: parent.width
            height: Math.round(88 * access.s)
            radius: Math.round(18 * access.s)
            color: access.card
            border.width: access.thick
            border.color: password.stateBorder

            LockPrompt {
                id: password

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Math.round(26 * access.s)
                anchors.rightMargin: Math.round(12 * access.s)
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height - 2 * access.thick
                unlock: access.ui.unlock
                unit: 1.5 * access.s
                chrome: "none"
                glyph: ""
                showButton: false
                placeholder: "Type your password"
                ink: access.fg
                dim: access.sub
                accent: access.acc
                errorColor: access.err
                restBorder: access.bd
            }
        }

        Item { width: 1; height: Math.round(14 * access.s) }

        // Caps Lock, another layout, what PAM said, another reader -- or,
        // with none of those, what to do.
        LockMessage {
            width: parent.width
            unlock: access.ui.unlock
            unit: 1.7 * access.s
            align: Text.AlignLeft
            ink: access.ui.unlock.resting ? access.err : access.fg
            warn: access.warn
        }

        Text {
            width: parent.width
            visible: !access.ui.unlock.message && !LockKeys.caps && !LockKeys.otherLayout
            text: access.ui.unlock.unlockedWithoutPassword
                ? "No password is needed. Press Unlock to continue."
                : "Type your password, then press Enter or Unlock."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            font.family: "Rubik"
            font.pixelSize: Math.round(22 * access.s)
            color: access.sub
        }

        Item { width: 1; height: Math.round(18 * access.s) }

        Rectangle {
            id: unlockButton

            function activate(): void {
                if (access.ui.unlock.unlockedWithoutPassword)
                    access.ui.unlock.confirm();
                else
                    password.submit();
            }

            width: parent.width
            height: Math.round(76 * access.s)
            radius: Math.round(18 * access.s)
            color: unlockHover.hovered && unlockButton.enabled ? Qt.lighter(access.acc, 1.08) : access.acc
            opacity: unlockButton.enabled ? 1 : 0.55
            enabled: !access.ui.unlock.resting
            activeFocusOnTab: true

            Row {
                anchors.centerIn: parent
                spacing: Math.round(12 * access.s)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "lock_open"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Math.round(28 * access.s)
                    color: access.accentFg
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Unlock"
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(22 * access.s)
                    font.weight: Font.Medium
                    color: access.accentFg
                }
            }

            Ring { target: unlockButton }

            HoverHandler { id: unlockHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: unlockButton.activate() }
            Keys.onSpacePressed: unlockButton.activate()
            Keys.onReturnPressed: unlockButton.activate()
            Keys.onEnterPressed: unlockButton.activate()

            Accessible.role: Accessible.Button
            Accessible.name: "Unlock"
            Accessible.description: access.ui.unlock.unlockedWithoutPassword
                ? "Unlocks the session. No password is needed."
                : "Sends the password and unlocks the session."
            Accessible.focusable: true
            Accessible.onPressAction: unlockButton.activate()
        }

        Item {
            width: 1
            height: Math.round(30 * access.s)
            visible: actions.visible
        }

        LockActions {
            id: actions

            visible: Options.showSessionButtons
            session: access.ui.session
            shape: "text"
            unit: 1.4 * access.s
            spacing: Math.round(40 * access.s)
            ink: access.fg
        }
    }

    // --- the caption strip -----------------------------------------------------

    Rectangle {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.round(76 * access.s)
        visible: access.captions && access.caption !== ""
        color: access.acc

        Text {
            id: stripGlyph

            x: access.margin
            anchors.verticalCenter: parent.verticalCenter
            text: "closed_caption"
            font.family: "Material Symbols Rounded"
            font.pixelSize: Math.round(28 * access.s)
            color: access.accentFg
        }

        Text {
            anchors.left: stripGlyph.right
            anchors.leftMargin: Math.round(16 * access.s)
            anchors.right: stripLabel.left
            anchors.rightMargin: Math.round(24 * access.s)
            anchors.verticalCenter: parent.verticalCenter
            text: access.caption
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: "Rubik"
            font.pixelSize: Math.round(21 * access.s)
            font.weight: Font.Medium
            color: access.accentFg
            // Announced from `say`, not read again as a label.
            Accessible.ignored: true
        }

        Text {
            id: stripLabel

            anchors.right: parent.right
            anchors.rightMargin: access.margin
            anchors.verticalCenter: parent.verticalCenter
            text: "Captions · what this screen announces"
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(16 * access.s)
            color: access.accentFg
            Accessible.ignored: true
        }
    }
}
