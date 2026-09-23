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
        if (unlock.resting || unlock.unlockedWithoutPassword || !password)
            return false;
        unlock.authenticator.respond(password);
        return true;
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
            unlock.say("Unlocking failed");
            unlock.rejected();
            restTimer.restart();
            messageTimer.restart();
        }

        function onSucceeded() {
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
            if (unlock.keepShown || unlock.resting)
                restart();
            else
                unlock.hide();
        }
    }
}
