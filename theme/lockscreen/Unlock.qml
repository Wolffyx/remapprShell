/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The part of the lock screen that decides whether the session unlocks.

    It talks to the greeter's authenticator (PamAuthenticators in
    kscreenlocker) and to nothing else, and it draws nothing, so the tests
    can hand it a fake and walk every path. A mistake here is not a cosmetic
    one: a lock screen that draws but cannot unlock can only be escaped from
    another virtual terminal.

    The rules are Plasma's own lock screen's, kept deliberately:

    - Authentication starts when the prompt shows. startAuthenticating() does
      nothing while authentication is already running, so calling it again
      is always safe.
    - After a failure the authenticator goes back to idle, and a password
      sent to an idle authenticator goes nowhere. So after the pause that
      follows a failure, authentication is started again. Without this the
      second attempt could never succeed.
    - A failure from a fingerprint or smartcard reader is not a wrong
      password, and is not treated as one.
    - When PAM lets the session go without asking anything, nothing quits
      until the person confirms: a lock screen that vanished on its own would
      look like it had never been locked.

    Plasma 6.8 added three rules of its own, and they are kept only where the
    greeter is that one -- asked of the authenticator, not of a version, by
    the property 6.8 brought in to pick an authenticator with. Before it,
    nothing below is done and nothing above changes.

    - While the prompt shows, startAuthenticating() is called every second,
      to keep the backend from going quiet. 6.8's own fallback locker, which
      draws when a lock screen does not load, dropped every password as
      "Received prompt response, but no pending prompt was found!" and never
      unlocked (2026-10-16).
    - On success, stopAuthenticating() first: whatever else is still
      authenticating, a reader or a timeout, is stopped before the greeter
      goes.
    - A password typed while the authenticator says its PAM conversation has
      timed out (`pamTimeout`, which 6.8's lock screen reads before any
      kscreenlocker has it) is held, and sent once it has not.
*/
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: unlock

    // PamAuthenticators, from the greeter's context. A test hands in a fake.
    required property var authenticator

    // How long input rests after a wrong password -- PAM delays the next
    // attempt anyway -- how long the failure stays said, and how long the
    // prompt stays with nothing happening.
    property int restMs: 3000
    property int messageMs: 3000
    property int idleMs: 10000
    property int awakeMs: 1000

    // The greeter from Plasma 6.8 on: see the top of this file.
    readonly property bool keepsAwake: !!unlock.authenticator && ("authenticator" in unlock.authenticator)

    // Let in: nothing is started again after this.
    property bool letIn: false

    // A password held while the PAM conversation has timed out, or empty.
    property string held: ""
    readonly property bool sending: unlock.held !== ""

    // Set by the prompt while something would be lost by hiding it: typed
    // text, the on-screen keyboard.
    property bool keepShown: false

    // Whether the prompt is showing. Only the clock shows otherwise.
    property bool shown: false

    readonly property bool resting: restTimer.running

    // Said under the password field: the failure, and whatever PAM has to
    // say (a lockout after too many attempts, an expiring password).
    property string message: ""

    // PAM let the session go without a prompt: the field becomes a button.
    property bool unlockedWithoutPassword: false

    // When the account stops being locked out, in milliseconds since the
    // epoch, and how long the lockout was when it was said -- or 0 and 0.
    // pam_faillock says it in words, "(10 minutes left to unlock)", once, and
    // a sentence that stays on screen goes stale; this is what lets the lock
    // screen count it down instead. Only ever drawn: nothing here waits for
    // it, because PAM is what refuses, and PAM keeps its own clock.
    property double lockedUntil: 0
    property double lockedSpan: 0

    // The readers that can unlock without typing, as kscreenlocker's flags.
    readonly property int fingerprint: 1
    readonly property int smartcard: 2
    readonly property int alternatives: (unlock.authenticator && unlock.authenticator.authenticatorTypes) || 0
    readonly property bool hasFingerprint: (unlock.alternatives & unlock.fingerprint) !== 0
    readonly property bool hasSmartcard: (unlock.alternatives & unlock.smartcard) !== 0

    // Passwords refused since the lock screen came up: wrong passwords, not
    // a reader failing. Counted here once rather than by each style that
    // says it, and counted before `rejected` so that a style told of a
    // refusal reads a count that includes it. Only ever drawn.
    property int refusals: 0

    signal clearPassword()
    signal rejected()
    signal messageRepeated()
    signal secretRequested()
    // A key, the pointer, a touch: anything poke() was told about. The frame
    // dims the screen after a while without one.
    signal activity()
    // The session is unlocked; the lock screen quits the greeter on this.
    signal finished()

    // Any sign of a person: a key, the pointer moving, a touch.
    function poke() {
        unlock.shown = true;
        idleTimer.restart();
        unlock.activity();
    }

    function hide() {
        unlock.shown = false;
    }

    // Escape: hide the prompt and forget what was typed.
    function dismiss() {
        unlock.held = "";
        unlock.hide();
        unlock.clearPassword();
    }

    // Sends a password. False when nothing was sent: the prompt was not
    // showing (the key that woke it is not a password), input is resting
    // after a failure, or there is nothing to send. An empty password is
    // never sent -- an account without one is let in without a prompt, so
    // an empty attempt could only ever count as a failure.
    function submit(password) {
        if (!unlock.shown) {
            unlock.poke();
            return false;
        }
        if (unlock.resting || unlock.sending || unlock.unlockedWithoutPassword || !password)
            return false;
        if (unlock.timedOut()) {
            unlock.held = password;
            unlock.authenticator.startAuthenticating();
            return true;
        }
        unlock.authenticator.respond(password);
        return true;
    }

    function timedOut(): bool {
        return unlock.authenticator?.pamTimeout === true;
    }

    // The held password, once the conversation is back.
    function sendHeld() {
        if (!unlock.sending || unlock.timedOut())
            return;
        unlock.authenticator.respond(unlock.held);
        unlock.held = "";
    }

    // The button shown when PAM asked for nothing.
    function confirm() {
        if (unlock.unlockedWithoutPassword)
            unlock.finished();
    }

    // pam_faillock's own sentence, in minutes. Anything else is not a lockout.
    function lockoutIn(text) {
        const m = /\((\d+) minutes? left to unlock\)/.exec(text || "");
        return m ? Number(m[1]) * 60000 : 0;
    }

    function say(text) {
        if (!text)
            return;
        const span = unlock.lockoutIn(text);
        if (span > 0) {
            unlock.lockedSpan = span;
            unlock.lockedUntil = Date.now() + span;
        }
        if (!unlock.message)
            unlock.message = text;
        else if (unlock.message.split("\n").includes(text))
            unlock.messageRepeated();
        else
            unlock.message += "\n" + text;
    }

    onShownChanged: {
        unlock.authenticator.startAuthenticating();
        if (unlock.shown)
            idleTimer.restart();
        else
            idleTimer.stop();
    }

    onKeepShownChanged: {
        if (unlock.shown)
            idleTimer.restart();
    }

    Connections {
        target: unlock.authenticator

        function onFailed(kind) {
            if (kind !== 0)
                return;
            unlock.refusals += 1;
            unlock.say("Unlocking failed");
            unlock.rejected();
            restTimer.restart();
            messageTimer.restart();
        }

        function onSucceeded() {
            unlock.letIn = true;
            unlock.held = "";
            if (unlock.keepsAwake)
                unlock.authenticator.stopAuthenticating();
            unlock.lockedUntil = 0;
            unlock.lockedSpan = 0;
            if (unlock.authenticator.hadPrompt) {
                unlock.finished();
            } else {
                unlock.unlockedWithoutPassword = true;
                unlock.poke();
            }
        }

        function onNoninteractiveError(kind, source) {
            unlock.say(source ? source.errorMessage : "");
            messageTimer.restart();
        }

        function onInfoMessageChanged() { unlock.say(unlock.authenticator.infoMessage); }
        function onErrorMessageChanged() { unlock.say(unlock.authenticator.errorMessage); }
        function onPromptChanged() { unlock.say(unlock.authenticator.prompt); }
        function onPromptForSecretChanged() { unlock.secretRequested(); }
    }

    Timer {
        id: restTimer
        interval: unlock.restMs
        onTriggered: {
            unlock.clearPassword();
            unlock.authenticator.startAuthenticating();
        }
    }

    Timer {
        id: messageTimer
        interval: unlock.messageMs
        onTriggered: unlock.message = ""
    }

    Timer {
        id: idleTimer
        interval: unlock.idleMs
        onTriggered: {
            if (unlock.keepShown || unlock.resting || unlock.sending)
                restart();
            else
                unlock.hide();
        }
    }

    // Plasma 6.8's heartbeat, and the held password's way out. Not while
    // resting: authentication starts again when the rest ends, as before.
    Timer {
        id: awakeTimer
        interval: unlock.awakeMs
        repeat: true
        running: (unlock.keepsAwake || unlock.sending) && unlock.shown && !unlock.resting && !unlock.letIn
        onTriggered: {
            unlock.authenticator.startAuthenticating();
            unlock.sendHeld();
        }
    }
}
