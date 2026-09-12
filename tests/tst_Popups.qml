// Tests for the shell's own notification popups: how long each stays, which
// are drawn, and what "Ask" finds.

import QtQuick
import QtTest
import qs.domain.notifications.popups

TestCase {
    name: "Popups"

    // ---- how long -------------------------------------------------------

    function test_our_default_when_the_application_leaves_it_to_us() {
        compare(Popups.timeoutFor(1, -1, 6000), 6000);
        compare(Popups.timeoutFor(0, undefined, 4000), 4000);
    }

    function test_the_applications_own_timeout_is_kept() {
        compare(Popups.timeoutFor(1, 10000, 6000), 10000);
    }

    function test_zero_is_until_closed() {
        compare(Popups.timeoutFor(1, 0, 6000), 0);
    }

    // As Plasma's: a critical notification stays, whatever it asks for.
    function test_critical_stays() {
        compare(Popups.timeoutFor(2, 3000, 6000), 0);
        compare(Popups.timeoutFor(2, -1, 6000), 0);
    }

    function test_nothing_flashes_past() {
        compare(Popups.timeoutFor(1, 200, 6000), 1500);
        compare(Popups.timeoutFor(1, -1, 0), 6000);
    }

    // ---- do not disturb --------------------------------------------------

    function test_do_not_disturb_holds_back_all_but_critical() {
        verify(Popups.admits(false, 1));
        verify(!Popups.admits(true, 0));
        verify(!Popups.admits(true, 1));
        verify(Popups.admits(true, 2));
    }

    // ---- which are drawn -------------------------------------------------

    function test_newest_first_and_at_most_max() {
        const got = Popups.arrange([{ id: 1, urgency: 1 }, { id: 3, urgency: 1 }, { id: 2, urgency: 1 }], 2);
        compare(got.map(x => x.id), [3, 2]);
    }

    function test_a_critical_one_is_not_pushed_off_by_newer_ones() {
        const got = Popups.arrange([{ id: 1, urgency: 2 }, { id: 2, urgency: 1 }, { id: 3, urgency: 1 }], 2);
        compare(got.map(x => x.id), [1, 3]);
    }

    function test_arrange_takes_nothing_gracefully() {
        compare(Popups.arrange(null, 5), []);
        compare(Popups.arrange([null, { id: 1, urgency: 1 }], 5).length, 1);
    }

    // ---- when they go ----------------------------------------------------

    function test_due_are_those_past_their_deadline() {
        compare(Popups.due({ 1: 1000, 2: 5000, 3: 0 }, 2000, -1), [1]);
    }

    function test_the_one_under_the_pointer_is_spared() {
        compare(Popups.due({ 1: 1000, 2: 1500 }, 2000, 1), [2]);
    }

    function test_let_go_of_it_gets_a_moment_more() {
        compare(Popups.released(1000, 5000), 7000);
        compare(Popups.released(9000, 5000), 9000);
        compare(Popups.released(0, 5000), 0);
    }

    // ---- ask -------------------------------------------------------------

    function test_ask_finds_the_newest_matching_entry() {
        const entries = [
            { appName: "A", summary: "s", body: "b", when: 3 },
            { appName: "A", summary: "s", body: "b", when: 1 }
        ];
        compare(Popups.historyIndex(entries, { appName: "A", summary: "s", body: "b" }), 0);
        compare(Popups.historyIndex(entries, { appName: "A", summary: "other", body: "b" }), -1);
        compare(Popups.historyIndex([], null), -1);
    }

    // ---- where -----------------------------------------------------------

    function test_auto_is_beside_the_clock() {
        compare(Popups.corner("auto", "bottom"), "bottom-right");
        compare(Popups.corner("auto", "top"), "top-right");
        compare(Popups.corner("auto", "left"), "top-right");
        compare(Popups.corner("top-left", "bottom"), "top-left");
        compare(Popups.corner("top-center", "bottom"), "top-center");
        compare(Popups.corner("bottom-center", "top"), "bottom-center");
        compare(Popups.corner("nonsense", "bottom"), "bottom-right");
    }

    // ---- what -------------------------------------------------------------

    function test_a_body_is_plain_text() {
        compare(Popups.plain("<b>Hi</b> &amp; <a href='x'>there</a><br/>next"), "Hi & there\nnext");
        compare(Popups.plain("1 &lt; 2"), "1 < 2");
        compare(Popups.plain(undefined), "");
    }

    function test_the_icon_prefers_the_image() {
        compare(Popups.iconOf("image://qsimage/1/2", "firefox").kind, "image");
        // A name in image clothing is looked up as a name, with a fallback.
        compare(Popups.iconOf("image://icon/dialog-information", ""), { kind: "name", value: "dialog-information" });
        compare(Popups.iconOf("", "/usr/share/icons/x.png").value, "file:///usr/share/icons/x.png");
        compare(Popups.iconOf("", "firefox").kind, "name");
        compare(Popups.iconOf("", "").value, "dialog-information");
    }
}
