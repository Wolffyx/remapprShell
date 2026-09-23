// Tests for the part of the lock screen that decides whether the session
// unlocks, against a stand-in for kscreenlocker's PamAuthenticators.
//
// The stand-in keeps the one rule of the real one that matters most here:
// startAuthenticating() does nothing while authentication is running, and a
// failure puts it back to idle -- after which a password goes nowhere until
// authentication is started again.

import QtQuick
import QtTest
import "../theme/lockscreen"

TestCase {
    id: tc
    name: "LockUnlock"

    Component {
        id: fakeAuthenticator

        QtObject {
            property int state: 0            // 0 idle, 1 authenticating
            property bool hadPrompt: false
            property string prompt: ""
            property string promptForSecret: ""
            property string infoMessage: ""
            property string errorMessage: ""
            property int authenticatorTypes: 0
            property var calls: []
            // What a password did: "sent" while authenticating, "lost" when idle.
            property var responses: []

            signal succeeded()
            signal failed(int kind, var source)
            signal noninteractiveError(int kind, var source)

            function startAuthenticating() {
                calls = calls.concat(["start"]);
                if (state === 1)
                    return;
                state = 1;
                hadPrompt = true;
                promptForSecret = promptForSecret === "Password: " ? "Password:" : "Password: ";
            }
            function respond(password) {
                responses = responses.concat([(state === 1 ? "sent:" : "lost:") + password]);
            }
            function wrongPassword() {
                state = 0;
                failed(0, null);
            }
            function starts() { return calls.filter(c => c === "start").length; }
        }
    }

    Component {
        id: unlockComponent
        Unlock {
            restMs: 40
            messageMs: 40
            idleMs: 80
        }
    }

    function make() {
        const auth = createTemporaryObject(fakeAuthenticator, tc);
        const unlock = createTemporaryObject(unlockComponent, tc, { authenticator: auth });
        verify(unlock, "Unlock instantiated");
        return { auth, unlock };
    }

    function spy(target, signalName) {
        const s = createTemporaryQmlObject("import QtTest; SignalSpy {}", tc);
        s.target = target;
        s.signalName = signalName;
        return s;
    }

    // ---- showing ----------------------------------------------------------

    function test_hidden_at_first_and_nothing_started() {
        const { auth, unlock } = make();
        verify(!unlock.shown);
        compare(auth.starts(), 0);
    }

    function test_showing_starts_authentication() {
        const { auth, unlock } = make();
        unlock.poke();
        verify(unlock.shown);
        compare(auth.state, 1);
        compare(auth.starts(), 1);
    }

    function test_the_key_that_wakes_it_is_not_a_password() {
        const { auth, unlock } = make();
        verify(!unlock.submit("hunter2"));
        verify(unlock.shown);
        compare(auth.responses, []);
    }

    // ---- the password -----------------------------------------------------

    function test_a_password_is_sent_once() {
        const { auth, unlock } = make();
        unlock.poke();
        verify(unlock.submit("hunter2"));
        compare(auth.responses, ["sent:hunter2"]);
    }

    function test_an_empty_password_is_never_sent() {
        const { auth, unlock } = make();
        unlock.poke();
        verify(!unlock.submit(""));
        compare(auth.responses, []);
    }

    // The one that matters: after a wrong password, the next one must reach
    // an authenticator that is listening again.
    function test_the_second_attempt_reaches_the_authenticator() {
        const { auth, unlock } = make();
        const cleared = spy(unlock, "clearPassword");
        unlock.poke();
        unlock.submit("wrong");
        auth.wrongPassword();

        verify(unlock.resting);
        verify(!unlock.submit("right"), "nothing is sent while resting");

        tryVerify(() => !unlock.resting, 1000);
        compare(cleared.count, 1);
        compare(auth.state, 1, "authentication started again");

        verify(unlock.submit("right"));
        compare(auth.responses, ["sent:wrong", "sent:right"]);
    }

    function test_a_failure_is_said_then_forgotten() {
        const { auth, unlock } = make();
        const rejected = spy(unlock, "rejected");
        unlock.poke();
        auth.wrongPassword();
        compare(unlock.message, "Unlocking failed");
        compare(rejected.count, 1);
        tryCompare(unlock, "message", "", 1000);
    }

    function test_the_same_failure_twice_is_not_said_twice() {
        const { auth, unlock } = make();
        const repeated = spy(unlock, "messageRepeated");
        unlock.poke();
        auth.wrongPassword();
        auth.wrongPassword();
        compare(unlock.message, "Unlocking failed");
        compare(repeated.count, 1);
    }

    function test_a_reader_failing_is_not_a_wrong_password() {
        const { auth, unlock } = make();
        unlock.poke();
        auth.failed(1, null);
        verify(!unlock.resting);
        compare(unlock.message, "");
    }

    function test_what_pam_says_is_shown() {
        const { auth, unlock } = make();
        unlock.poke();
        auth.errorMessage = "The account is locked due to 3 failed logins.";
        auth.infoMessage = "(10 minute(s) left to unlock)";
        compare(unlock.message, "The account is locked due to 3 failed logins.\n(10 minute(s) left to unlock)");
    }

    function test_asking_for_the_secret_moves_the_keyboard_there() {
        const { auth, unlock } = make();
        const asked = spy(unlock, "secretRequested");
        unlock.poke();
        compare(asked.count, 1);
    }

    // ---- unlocking --------------------------------------------------------

    function test_success_after_a_prompt_finishes() {
        const { auth, unlock } = make();
        const finished = spy(unlock, "finished");
        unlock.poke();
        unlock.submit("right");
        auth.succeeded();
        compare(finished.count, 1);
    }

    function test_success_without_a_prompt_waits_for_the_person() {
        const { auth, unlock } = make();
        const finished = spy(unlock, "finished");
        auth.hadPrompt = false;
        auth.succeeded();
        verify(unlock.unlockedWithoutPassword);
        verify(unlock.shown);
        compare(finished.count, 0);
        verify(!unlock.submit("anything"));
        unlock.confirm();
        compare(finished.count, 1);
    }

    function test_confirm_does_nothing_while_locked() {
        const { auth, unlock } = make();
        const finished = spy(unlock, "finished");
        unlock.confirm();
        compare(finished.count, 0);
    }

    // ---- hiding -----------------------------------------------------------

    function test_an_idle_prompt_hides() {
        const { auth, unlock } = make();
        unlock.poke();
        tryCompare(unlock, "shown", false, 1000);
    }

    function test_typed_text_keeps_it_up() {
        const { auth, unlock } = make();
        unlock.keepShown = true;
        unlock.poke();
        wait(200);
        verify(unlock.shown);
        unlock.keepShown = false;
        tryCompare(unlock, "shown", false, 1000);
    }

    function test_escape_hides_and_forgets() {
        const { auth, unlock } = make();
        const cleared = spy(unlock, "clearPassword");
        unlock.poke();
        unlock.dismiss();
        verify(!unlock.shown);
        compare(cleared.count, 1);
    }

    function test_hiding_and_showing_again_keeps_one_conversation() {
        const { auth, unlock } = make();
        unlock.poke();
        unlock.hide();
        unlock.poke();
        compare(auth.state, 1);
        verify(unlock.submit("right"));
        compare(auth.responses, ["sent:right"]);
    }

    // ---- other ways in ----------------------------------------------------

    function test_readers_are_offered() {
        const { auth, unlock } = make();
        compare(unlock.alternatives, 0);
        auth.authenticatorTypes = 3;
        verify(unlock.alternatives & unlock.fingerprint);
        verify(unlock.alternatives & unlock.smartcard);
    }

    // ---- what is only drawn ----------------------------------------------

    function test_a_lockout_is_counted_from_what_pam_said() {
        const { auth, unlock } = make();
        compare(unlock.lockedUntil, 0);
        const before = Date.now();
        auth.errorMessage = "The account is locked due to 3 failed logins.";
        compare(unlock.lockedUntil, 0, "the reason alone is not a duration");
        auth.infoMessage = "(10 minutes left to unlock)";
        compare(unlock.lockedSpan, 600000);
        verify(unlock.lockedUntil >= before + 600000);
        verify(unlock.message.includes("10 minutes left"), "and it is still said");
    }

    function test_one_minute_is_a_lockout_too() {
        const { auth, unlock } = make();
        auth.infoMessage = "(1 minute left to unlock)";
        compare(unlock.lockedSpan, 60000);
    }

    function test_letting_in_forgets_the_lockout() {
        const { auth, unlock } = make();
        auth.infoMessage = "(3 minutes left to unlock)";
        verify(unlock.lockedUntil > 0);
        unlock.poke();
        auth.succeeded();
        compare(unlock.lockedUntil, 0);
        compare(unlock.lockedSpan, 0);
    }

    function test_any_sign_of_a_person_is_activity() {
        const { unlock } = make();
        const s = spy(unlock, "activity");
        unlock.poke();
        unlock.poke();
        compare(s.count, 2);
    }
}
