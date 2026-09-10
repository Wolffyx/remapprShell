// Tests for which tray icon goes where.
//
// The rules are small and every one of them has a way of being wrong that a
// person would notice immediately and struggle to explain: icons vanishing,
// a chevron with nothing behind it, an application that closes and leaves a
// gap, a hidden icon coming back. So they are pinned here rather than left to
// be discovered on the panel.

import QtQuick
import QtTest
import qs.domain.tray.layout

TestCase {
    name: "TrayLayout"

    function items(ids) {
        return ids.map(id => ({ id: id }));
    }

    function ids(list) {
        return list.map(i => i.id);
    }

    // A fresh install has no pinned list, and must not show an empty strip
    // with the whole tray behind a chevron -- that reads as broken.
    function test_nothing_pinned_shows_everything() {
        const s = TrayLayout.split(items(["a", "b", "c"]), [], []);
        compare(ids(s.shown), ["a", "b", "c"]);
        compare(s.overflow.length, 0);
    }

    function test_pinning_moves_the_rest_behind_the_chevron() {
        const s = TrayLayout.split(items(["a", "b", "c"]), ["b"], []);
        compare(ids(s.shown), ["b"]);
        compare(ids(s.overflow), ["a", "c"]);
    }

    // The panel order is the order the user left them in, not the order the
    // host happens to report.
    function test_pinned_order_is_the_panel_order() {
        const s = TrayLayout.split(items(["a", "b", "c"]), ["c", "a"], []);
        compare(ids(s.shown), ["c", "a"]);
        compare(ids(s.overflow), ["b"]);
    }

    // An application that is closed should not leave a gap where its icon was.
    function test_a_pinned_id_that_is_not_running_is_absent() {
        const s = TrayLayout.split(items(["a", "c"]), ["a", "b", "c"], []);
        compare(ids(s.shown), ["a", "c"]);
        compare(s.overflow.length, 0);
    }

    function test_hidden_is_never_shown_anywhere() {
        const s = TrayLayout.split(items(["a", "b", "c"]), [], ["b"]);
        compare(ids(s.shown), ["a", "c"]);
        compare(s.overflow.length, 0);
        compare(ids(s.hidden), ["b"]);
    }

    // An id in both lists is a leftover, not a contradiction to resolve: the
    // one that says "never show me" is the one to obey.
    function test_hidden_beats_pinned() {
        const s = TrayLayout.split(items(["a", "b"]), ["a", "b"], ["b"]);
        compare(ids(s.shown), ["a"]);
        compare(ids(s.hidden), ["b"]);
    }

    // Hiding everything must not fall back to showing everything, which is
    // what an empty result would do if the empty-pinned rule were applied to
    // the wrong list.
    function test_hiding_everything_leaves_nothing() {
        const s = TrayLayout.split(items(["a", "b"]), [], ["a", "b"]);
        compare(s.shown.length, 0);
        compare(s.overflow.length, 0);
    }

    function test_a_repeated_pin_is_not_a_repeated_icon() {
        const s = TrayLayout.split(items(["a", "b"]), ["a", "a"], []);
        compare(ids(s.shown), ["a"]);
        compare(ids(s.overflow), ["b"]);
    }

    function test_an_empty_tray_is_not_an_error() {
        const s = TrayLayout.split([], ["a"], ["b"]);
        compare(s.shown.length, 0);
        compare(s.overflow.length, 0);
        compare(s.hidden.length, 0);
    }

    function test_nothing_at_all_is_not_an_error() {
        const s = TrayLayout.split(undefined, undefined, undefined);
        compare(s.shown.length, 0);
        compare(s.overflow.length, 0);
    }

    // The settings page draws from this, and a hidden id that is not running
    // must stay on the page or it could never be brought back.
    function test_the_page_keeps_a_hidden_id_that_is_not_running() {
        const s = TrayLayout.splitIds(items(["a"]), [], ["b"]);
        compare(s.shown, ["a"]);
        compare(s.hidden, ["b"]);
    }

    function test_the_page_and_the_panel_agree() {
        const list = items(["a", "b", "c"]);
        const s = TrayLayout.split(list, ["c"], ["a"]);
        const p = TrayLayout.splitIds(list, ["c"], ["a"]);
        compare(p.shown, ids(s.shown));
        compare(p.overflow, ids(s.overflow));
    }
}
