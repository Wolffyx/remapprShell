// Tests for where a click on a tray icon was, and which waiting clicks a
// reading of the tray's bus addresses answers.
//
// The point is handed to the application, and some open their window at it:
// a wrong one is a window in the corner of the layout, or on the screen next
// to the tray, which reads as KWin placing it badly. Every way it went wrong
// is pinned here -- the origin sent when no screen was known, and a screen
// left of the origin clamped onto its neighbour.

import QtQuick
import QtTest
import qs.domain.tray.click

TestCase {
    name: "TrayClick"

    // This machine's screens: a landscape one, and a portrait one to its
    // right reaching above it.
    readonly property var dp2: ({ name: "DP-2", x: 0, y: 1040, width: 2560, height: 1440 })
    readonly property var dp3: ({ name: "DP-3", x: 2560, y: 0, width: 1440, height: 2560 })

    // A screen left of the first, and one above it: KWin numbers both from
    // the same origin, so theirs are negative.
    readonly property var leftOfOrigin: ({ name: "HDMI-1", x: -1920, y: 0, width: 1920, height: 1080 })
    readonly property var aboveOrigin: ({ name: "HDMI-2", x: 0, y: -1080, width: 1920, height: 1080 })

    function test_the_point_is_the_icon_at_the_inner_edge_of_a_bottom_panel() {
        compare(TrayClick.point(dp2, "bottom", 60, { x: 2300, y: 20 }, [dp2, dp3]), { x: 2300, y: 2420 });
    }

    function test_the_point_is_the_icon_at_the_inner_edge_of_every_other_edge() {
        compare(TrayClick.point(dp3, "top", 60, { x: 400, y: 10 }, [dp2, dp3]), { x: 2960, y: 60 });
        compare(TrayClick.point(dp2, "left", 60, { x: 10, y: 700 }, [dp2, dp3]), { x: 60, y: 1740 });
        compare(TrayClick.point(dp3, "right", 60, { x: 10, y: 900 }, [dp2, dp3]), { x: 3940, y: 900 });
    }

    // Clamped to 0, these put the window on the neighbouring screen.
    function test_a_screen_left_of_or_above_the_origin_keeps_its_negative_point() {
        compare(TrayClick.point(leftOfOrigin, "bottom", 48, { x: 1800, y: 5 }, [leftOfOrigin, dp2]),
                { x: -120, y: 1032 });
        compare(TrayClick.point(aboveOrigin, "top", 48, { x: 100, y: 5 }, [aboveOrigin, dp2]),
                { x: 100, y: -1032 });
        compare(TrayClick.point(leftOfOrigin, "left", 48, { x: 5, y: 600 }, [leftOfOrigin]),
                { x: -1872, y: 600 });
    }

    function test_an_edge_nobody_named_is_the_bottom() {
        compare(TrayClick.point(dp2, undefined, 60, { x: 100, y: 20 }, [dp2]), { x: 100, y: 2420 });
        compare(TrayClick.point(dp2, "sideways", 60, { x: 100, y: 20 }, [dp2]), { x: 100, y: 2420 });
    }

    // Activate takes integers, and a scaled panel's places are not.
    function test_the_point_is_in_whole_pixels() {
        compare(TrayClick.point(dp2, "bottom", 45.5, { x: 100.6, y: 3 }, [dp2]), { x: 101, y: 2435 });
    }

    // What sent Toolbox to the top-left corner: no screen, and so 0,0.
    function test_no_screen_is_the_middle_of_the_first_screen_not_the_origin() {
        const p = TrayClick.point(null, "bottom", 60, { x: 2300, y: 20 }, [dp2, dp3]);
        compare(p, { x: 1280, y: 1760 });
        verify(p.x !== 0 || p.y !== 0, "a click with no screen still went to the origin");
        compare(TrayClick.point(undefined, "bottom", 60, null, [dp3]), { x: 3280, y: 1280 });
    }

    function test_a_screen_without_the_icons_place_is_its_middle() {
        compare(TrayClick.point(dp3, "bottom", 60, null, [dp2, dp3]), { x: 3280, y: 1280 });
        compare(TrayClick.point(leftOfOrigin, undefined, undefined, null, []), { x: -960, y: 540 });
    }

    function test_no_screen_anywhere_is_the_origin() {
        compare(TrayClick.point(null, "bottom", 60, { x: 10, y: 10 }, []), { x: 0, y: 0 });
        compare(TrayClick.point(null, "bottom", 60, null, undefined), { x: 0, y: 0 });
    }

    function test_the_middle_of_a_screen() {
        compare(TrayClick.centre(dp2), { x: 1280, y: 1760 });
        compare(TrayClick.centre(aboveOrigin), { x: 960, y: -540 });
        compare(TrayClick.centre(null), { x: 0, y: 0 });
    }

    function ids(list) {
        return list.map(w => w.id);
    }

    // The race: an application has just registered, a reading already under
    // way does not know it, and the click on it waited for that reading and
    // fell back to 0,0 -- when the reading queued behind it would have found it.
    function test_a_reading_begun_before_a_click_does_not_answer_it() {
        const s = TrayClick.due([{ id: "toolbox", after: 3 }], 3);
        compare(ids(s.due), []);
        compare(ids(s.waiting), ["toolbox"]);
    }

    function test_a_reading_begun_after_a_click_answers_it() {
        const s = TrayClick.due([{ id: "toolbox", after: 3 }], 4);
        compare(ids(s.due), ["toolbox"]);
        compare(ids(s.waiting), []);
    }

    function test_each_click_is_answered_by_its_own_reading_in_the_order_made() {
        const s = TrayClick.due([{ id: "a", after: 2 }, { id: "b", after: 3 }, { id: "c", after: 1 }], 3);
        compare(ids(s.due), ["a", "c"]);
        compare(ids(s.waiting), ["b"]);
    }

    function test_nothing_waiting_is_nothing_due() {
        compare(TrayClick.due([], 1), { due: [], waiting: [] });
        compare(TrayClick.due(undefined, 1), { due: [], waiting: [] });
    }
}
