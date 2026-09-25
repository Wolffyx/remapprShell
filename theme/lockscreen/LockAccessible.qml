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

    This file keeps the choices and the words; what they make of the page is
    AccessibleLook, and the page is drawn by the Accessible* parts beside it
    -- the bar of choices, the cards under the clock, the way in, and the
    caption strip.
*/
pragma ComponentBehavior: Bound

import QtQuick

LockStyle {
    id: access

    // --- this lock's choices ---------------------------------------------

    // The text size, as the design offers it; everything but the page's own
    // margins is drawn at `s`.
    property real size: 1.2
    property string contrast: "high"
    property bool captions: true

    readonly property real s: access.unit * access.size

    // The design's two palettes, and the borders drawn at `s`.
    readonly property AccessibleLook look: AccessibleLook {
        s: access.s
        contrast: access.contrast
        accent: access.ui.accent
    }

    readonly property int margin: Math.round(80 * access.unit)
    readonly property int fade: access.reduceMotion ? 0 : 250

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: right.field
    promptBlock: right.button

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

    // The characters typed so far, and why the count went down.
    property int typed: 0

    Connections {
        target: right.field
        function onTextChanged() {
            const n = right.field.text.length;
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
        target: right.field.field
        function onShowPasswordChanged() {
            access.say(right.field.field.showPassword ? "Password shown." : "Password hidden.", true);
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

    // --- the page ----------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: access.look.bg
    }

    // --- the choices -------------------------------------------------------

    AccessibleChoices {
        id: choices

        x: access.margin
        y: Math.round(64 * access.unit)
        width: access.width - 2 * access.margin
        ui: access.ui
        look: access.look
        size: access.size
        contrast: access.contrast
        captions: access.captions
        reduceMotion: access.reduceMotion
        opacity: access.ui.unlock.shown ? 1 : 0
        enabled: access.ui.unlock.shown

        Behavior on opacity { NumberAnimation { duration: access.fade } }

        onSizeChosen: (value, label) => {
            access.size = value;
            access.say(`Text size ${label}.`, true);
        }
        onContrastChosen: (value, label) => {
            access.contrast = value;
            access.say(`${label} contrast.`, true);
        }
        onCaptionsToggled: {
            access.captions = !access.captions;
            access.say(access.captions ? "Captions on." : "Captions off.", true);
        }
        onKeyboardToggled: {
            const showing = !access.ui.keyboardShown;
            access.ui.toggleKeyboard();
            access.say(showing ? "On-screen keyboard shown." : "On-screen keyboard hidden.", true);
        }
        onMotionToggled: {
            access.reduceMotion = !access.reduceMotion;
            access.say(access.reduceMotion ? "Reduce motion on." : "Reduce motion off.", true);
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
            ink: access.look.fg
            dateInk: access.look.sub
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

        AccessibleFacts {
            width: parent.width
            ui: access.ui
            look: access.look
        }
    }

    // --- the prompt ----------------------------------------------------------

    AccessiblePrompt {
        id: right

        x: access.rightX
        y: access.colTop
        width: access.width - access.rightX - access.margin
        ui: access.ui
        look: access.look
        opacity: access.ui.unlock.shown ? 1 : 0
        enabled: access.ui.unlock.shown

        Behavior on opacity { NumberAnimation { duration: access.fade } }
    }

    // --- the caption strip -----------------------------------------------------

    AccessibleCaptions {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: access.captions && access.caption !== ""
        look: access.look
        caption: access.caption
        margin: access.margin
    }
}
