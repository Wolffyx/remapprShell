import QtQuick
import QtTest
import qs.domain.sidebar.gesture

TestCase {
    name: "Gesture"

    // This machine's portrait screen, to the right of a landscape one and
    // reaching above it: its edge is the one the sidebar comes out of.
    readonly property var dp2: ({ name: "DP-2", x: 0, y: 1040, width: 2560, height: 1440 })
    readonly property var dp3: ({ name: "DP-3", x: 2560, y: 0, width: 1440, height: 2560 })

    function test_the_grip_is_where_the_pointer_was_pushed_in() {
        // In the screen's own coordinates: DP-2 starts 1040 down.
        compare(Gesture.gripCentre(1640, 1040, 1440, 72), 600);
        compare(Gesture.gripCentre(812, 0, 2560, 72), 812);
    }

    function test_the_grip_stays_wholly_on_the_screen() {
        compare(Gesture.gripCentre(1041, 1040, 1440, 72), 36);
        compare(Gesture.gripCentre(2479, 1040, 1440, 72), 1404);
        // Longer than the surface: in the middle of it.
        compare(Gesture.gripCentre(10, 0, 40, 72), 20);
    }

    function test_a_pointer_nobody_reported_puts_the_grip_in_the_middle() {
        compare(Gesture.gripCentre(-1, 0, 2560, 72), 1280);
        compare(Gesture.gripCentre(undefined, 0, 1440, 72), 720);
    }

    function test_the_band_is_the_grip_and_its_slack_on_the_surface() {
        compare(Gesture.band(600, 72, 24, 1440), { y: 540, height: 120 });
        // Cut off at the ends rather than hanging off them.
        compare(Gesture.band(36, 72, 24, 1440), { y: 0, height: 96 });
        compare(Gesture.band(1404, 72, 24, 1440), { y: 1344, height: 96 });
    }

    function test_inwards_is_away_from_the_edge() {
        compare(Gesture.inward(40, true), 40);
        compare(Gesture.inward(-40, false), 40);
        compare(Gesture.inward(40, false), -40);
    }

    function test_the_sidebar_follows_the_pull_past_the_dead_zone() {
        compare(Gesture.progress(Gesture.deadZone, 412), 0);
        compare(Gesture.progress(Gesture.deadZone + 206, 412), 0.5);
        compare(Gesture.progress(10000, 412), 1);
        // Pushed back out past where it started: not less than shut.
        compare(Gesture.progress(-50, 412), 0);
        compare(Gesture.progress(50, 0), 1);
    }

    function test_letting_go_past_a_third_leaves_it_open() {
        compare(Gesture.settlesOpen(Gesture.openAt, 0), true);
        compare(Gesture.settlesOpen(Gesture.openAt - 0.01, 0), false);
    }

    function test_a_flick_decides_whatever_the_distance() {
        compare(Gesture.settlesOpen(0.1, Gesture.flick), true);
        compare(Gesture.settlesOpen(0.9, -Gesture.flick), false);
        // Not a flick if it never came out at all.
        compare(Gesture.settlesOpen(0, Gesture.flick), false);
    }

    function test_the_offset_is_towards_its_own_edge() {
        compare(Gesture.offset(0, 412, false), 412);
        compare(Gesture.offset(0, 412, true), -412);
        compare(Gesture.offset(1, 412, false), 0);
        compare(Gesture.offset(0.5, 412, true), -206);
        compare(Gesture.offset(2, 412, false), 0);
    }

    function test_the_screen_is_found_by_name_then_by_point() {
        const both = [dp2, dp3];
        compare(Gesture.screenFor("DP-3", 0, 0, both), "DP-3");
        // A name nobody has: the point decides.
        compare(Gesture.screenFor("HDMI-9", 100, 1100, both), "DP-2");
        compare(Gesture.screenFor("", 3999, 812, both), "DP-3");
        // Neither: nobody's, which is the first screen to whoever asks.
        compare(Gesture.screenFor("", -1, -1, both), "");
        compare(Gesture.screenFor("", 100, 100, both), "");
    }
}
