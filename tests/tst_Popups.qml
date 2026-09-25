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

    // ---- what a click acts on ---------------------------------------------
    //
    // The hints in these cases were read off the session bus on 2026-09-16
    // while Spectacle saved a screenshot, rather than made up: the array form
    // of x-kde-urls and a "default" action called "Open" are what it sends.

    function test_urls_are_local_files_only() {
        compare(Popups.urlsOf({ "x-kde-urls": ["file:///home/a/shot.png"] }), ["file:///home/a/shot.png"]);
        compare(Popups.urlsOf({ "x-kde-urls": "/home/a/shot.png" }), ["file:///home/a/shot.png"]);
        compare(Popups.urlsOf({ "x-kde-urls": ["https://example.com/x.png"] }), []);
        compare(Popups.urlsOf({}), []);
        compare(Popups.urlsOf(undefined), []);
    }

    // The same hint as busctl hands it to the history: the hint wrapped as
    // { type, data }, and an array of variants wrapped element by element.
    // One rule reads both, so the history and the popup cannot disagree.
    function test_urls_read_through_the_bus_wrapping() {
        compare(Popups.urlsOf({ "x-kde-urls": { type: "as", data: ["file:///home/a/shot.png"] } }),
                ["file:///home/a/shot.png"]);
        compare(Popups.urlsOf({ "x-kde-urls": { type: "s", data: "/home/a/shot.png" } }),
                ["file:///home/a/shot.png"]);
        compare(Popups.urlsOf({ "x-kde-urls": { type: "av", data: [{ type: "s", data: "/home/a/x.pdf" },
                                                                   { type: "s", data: "https://example.com/" }] } }),
                ["file:///home/a/x.pdf"]);
        compare(Popups.urlsOf({ "x-kde-urls": { type: "as", data: [] } }), []);
        compare(Popups.urlsOf({ "x-kde-urls": [null, "", "  /home/a/y.png  "] }), ["file:///home/a/y.png"]);
    }

    function test_unwrapped_leaves_plain_values_alone() {
        compare(Popups.unwrapped({ type: "s", data: "x" }), "x");
        compare(Popups.unwrapped("x"), "x");
        compare(Popups.unwrapped(["x"]), ["x"]);
        compare(Popups.unwrapped(null), null);
        compare(Popups.unwrapped(undefined), undefined);
    }

    function test_a_picture_is_a_file_that_looks_like_one() {
        compare(Popups.pictureOf({ "x-kde-urls": ["file:///home/a/Screenshot.png"] }), "file:///home/a/Screenshot.png");
        compare(Popups.pictureOf({ "image-path": "/home/a/photo.JPG" }), "file:///home/a/photo.JPG");
        // A name, not a file: what `notify-send -i` sends.
        compare(Popups.pictureOf({ "image-path": "dialog-information" }), "");
        // A file that is not a picture is not drawn as one.
        compare(Popups.pictureOf({ "x-kde-urls": ["file:///home/a/report.pdf"] }), "");
        compare(Popups.pictureOf({}), "");
    }

    function test_a_click_prefers_the_senders_own_action() {
        const withDefault = { actions: [{ identifier: "default", text: "Open" }], desktopEntry: "org.kde.spectacle" };
        compare(Popups.openTarget(withDefault, { "x-kde-urls": ["file:///a/s.png"] }).kind, "action");

        // No default action: the file it named, then the application itself.
        // This is the whole of the bug -- a click used to close the popup and
        // do nothing else.
        const quiet = { actions: [{ identifier: "1", text: "Annotate" }], desktopEntry: "org.kde.spectacle" };
        compare(Popups.openTarget(quiet, { "x-kde-urls": ["file:///a/s.png"] }),
                { kind: "url", value: "file:///a/s.png" });
        compare(Popups.openTarget(quiet, {}), { kind: "app", value: "org.kde.spectacle" });
        compare(Popups.openTarget({ actions: [], desktopEntry: "firefox.desktop" }, {}).value, "firefox");
        compare(Popups.openTarget({ actions: [] }, {}).kind, "none");
        compare(Popups.openTarget(null, {}).kind, "none");
    }

    // "USB Device Detected": no actions, sent by kded, and a click started a
    // second kded -- nothing anybody could see.
    function test_a_device_plugged_in_opens_the_devices() {
        const usb = { actions: [], desktopEntry: "org.kde.kded6", appIcon: "drive-removable-media-usb" };
        compare(Popups.openTarget(usb, { "x-kde-eventId": "deviceAdded" }).kind, "devices");
    }

    function test_a_screen_plugged_in_opens_the_display_settings() {
        const screen = { actions: [], desktopEntry: "org.kde.kded6", appIcon: "video-display" };
        compare(Popups.openTarget(screen, { "x-kde-eventId": "deviceAdded" }).kind, "displays");
    }

    function test_a_service_is_never_started_as_an_application() {
        compare(Popups.openTarget({ actions: [], desktopEntry: "org.kde.kded6" }, {}).kind, "none");
        compare(Popups.openTarget({ actions: [], desktopEntry: "org.kde.plasmashell.desktop" }, {}).kind, "none");
        compare(Popups.openTarget({ actions: [], desktopEntry: "org.kde.kded6" },
                                  { "x-kde-eventId": "deviceRemoved" }).kind, "none");
    }

    function test_the_history_reads_the_same_rule() {
        compare(Popups.targetFor({ eventId: "deviceAdded", desktopEntry: "org.kde.kded6" }).kind, "devices");
        compare(Popups.targetFor({ url: "file:///a/b.png", eventId: "deviceAdded" }).kind, "url");
        compare(Popups.targetFor({}).kind, "none");
    }
}
