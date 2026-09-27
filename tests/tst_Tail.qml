// The bridge a popout takes the pointer across, from its widget to its card.
//
// What these hold is where it lands and how wide it is: a bridge that missed
// its button, or ran off the card, is a number before it is a closed preview.

import QtQuick
import QtTest
import qs.domain.panel

TestCase {
    name: "Tail"

    // This machine's panel: popouts 12 px clear of it, and a taskbar button
    // 48 px wide -- the bridge is the button's own width.
    readonly property int span: 12
    readonly property int button: 48

    // ---- where it lands ---------------------------------------------------

    function test_centred_on_the_button() {
        const b = Tail.bridge(400, 200, button, span);
        compare(b.at, 200);
        compare(b.width, button);
        compare(b.span, span);
    }

    function test_a_point_off_the_card_is_brought_back_onto_it() {
        compare(Tail.bridge(400, -50, button, span).at, button / 2);
        compare(Tail.bridge(400, 1000, button, span).at, 400 - button / 2);
    }

    function test_never_wider_than_the_card() {
        const b = Tail.bridge(30, 15, button, span);
        compare(b.width, 30);
        compare(b.at, 15);
    }

    function test_no_gap_is_no_depth() {
        compare(Tail.bridge(400, 200, button, -4).span, 0);
    }

    // ---- the rectangle, on every edge -------------------------------------

    function test_below_the_card_on_a_bottom_panel() {
        const b = Tail.bridge(400, 100, button, span);
        const r = Tail.box(b, 400, 300, "bottom", 10, 20);
        compare(r.x, 10 + 100 - button / 2);
        compare(r.y, 20 + 300);
        compare(r.width, button);
        compare(r.height, span);
    }

    function test_above_the_card_on_a_top_panel() {
        const r = Tail.box(Tail.bridge(400, 100, button, span), 400, 300, "top", 0, 0);
        compare(r.x, 100 - button / 2);
        compare(r.y, -span);
        compare(r.width, button);
        compare(r.height, span);
    }

    function test_beside_the_card_on_a_side_panel() {
        const left = Tail.box(Tail.bridge(300, 150, button, span), 400, 300, "left", 0, 0);
        compare(left.x, -span);
        compare(left.y, 150 - button / 2);
        compare(left.width, span);
        compare(left.height, button);

        const right = Tail.box(Tail.bridge(300, 150, button, span), 400, 300, "right", 0, 0);
        compare(right.x, 400);
        compare(right.width, span);
        compare(right.height, button);
    }
}
