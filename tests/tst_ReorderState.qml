// Tests for dragging a row to a new place in a list.
//
// Two settings pages reorder by dragging -- the widgets on the panel and the
// tray's three lists -- and both used to carry their own copy of this
// arithmetic. It is the part that is easy to get off by one: which rows make
// way, which way they move, and where a drop past either end lands.

import QtQuick
import QtTest
import qs.ui.controls

TestCase {
    name: "ReorderState"

    Component {
        id: stateFactory
        ReorderState { }
    }

    Component {
        id: spyFactory
        SignalSpy { signalName: "dropped" }
    }

    function reorder(rows, props) {
        const s = createTemporaryObject(stateFactory, this, Object.assign({
            rowHeight: 40, minIndex: 0, maxIndex: rows - 1
        }, props ?? {}));
        return s;
    }

    function spyOn(s) {
        return createTemporaryObject(spyFactory, this, { target: s });
    }

    // Nothing held, nothing moves.
    function test_no_drag_moves_nothing() {
        const s = reorder(5);
        for (let i = 0; i < 5; i++)
            compare(s.shift(i), 0);
    }

    // Held at 1 and taken down to 3: the two it passed move up a row to fill
    // the gap it left, and the rest stay put. The held row is the grip's to
    // move, not this.
    function test_dragging_down_moves_the_passed_rows_up() {
        const s = reorder(5);
        s.begin(1);
        s.track(1, 85);
        compare(s.dropIndex, 3);
        compare(s.shift(0), 0);
        compare(s.shift(1), 0);
        compare(s.shift(2), -40);
        compare(s.shift(3), -40);
        compare(s.shift(4), 0);
    }

    function test_dragging_up_moves_the_passed_rows_down() {
        const s = reorder(5);
        s.begin(3);
        s.track(3, -75);
        compare(s.dropIndex, 1);
        compare(s.shift(0), 0);
        compare(s.shift(1), 40);
        compare(s.shift(2), 40);
        compare(s.shift(3), 0);
        compare(s.shift(4), 0);
    }

    // Under half a row is not a step.
    function test_less_than_half_a_row_stays() {
        const s = reorder(5);
        s.begin(2);
        s.track(2, 19);
        compare(s.dropIndex, 2);
        s.track(2, -19);
        compare(s.dropIndex, 2);
    }

    // Past either end, it lands at that end -- and a list with a heading at
    // the top never puts a row above it.
    function test_a_drop_past_the_ends_is_clamped() {
        const s = reorder(5);
        s.begin(2);
        s.track(2, 4000);
        compare(s.dropIndex, 4);
        s.track(2, -4000);
        compare(s.dropIndex, 0);

        const headed = reorder(5, { minIndex: 1 });
        headed.begin(2);
        headed.track(2, -4000);
        compare(headed.dropIndex, 1);
    }

    // Released somewhere new: said once, from and to, and the state is clear
    // for the next drag.
    function test_release_says_where_it_went() {
        const s = reorder(5);
        const spy = spyOn(s);
        s.begin(0);
        s.track(0, 80);
        s.end();
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0], 0);
        compare(spy.signalArguments[0][1], 2);
        compare(s.dragIndex, -1);
        compare(s.dropIndex, -1);
        compare(s.shift(1), 0);
    }

    // Released where it began, it went nowhere, and nothing is written.
    function test_release_in_place_says_nothing() {
        const s = reorder(5);
        const spy = spyOn(s);
        s.begin(3);
        s.track(3, 10);
        s.end();
        compare(spy.count, 0);
    }

    // A release with no drag behind it -- the handler's active flag going
    // false twice, say -- is not a move from row -1.
    function test_release_without_a_drag_says_nothing() {
        const s = reorder(5);
        const spy = spyOn(s);
        s.end();
        compare(spy.count, 0);
    }
}
