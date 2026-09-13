// Tests for how many columns of cards a settings page gets.
//
// This is four numbers and a Math.min, and it is still the part of a layout
// that goes wrong quietly: a grid that gives a lone card half the page, one
// that squeezes two columns into a narrow window until every description wraps
// to four lines, or one that divides by a column count of zero and hands every
// card a NaN width -- which draws nothing at all and looks like a page that
// failed to load.

import QtQuick
import QtTest
import qs.ui.primitives

TestCase {
    name: "CardGrid"

    Component {
        id: gridFactory
        CardGrid { }
    }

    function grid(width, count) {
        const g = createTemporaryObject(gridFactory, this);
        g.width = width;
        g.count = count;
        return g;
    }

    // The window at its usual size: two columns, each card half the room less
    // the gap between them.
    function test_a_wide_page_gets_two_columns() {
        const g = grid(900, 4);
        compare(g.columns, 2);
        compare(g.cellWidth, (900 - g.spacing) / 2);
    }

    // Narrower than two minimum cards and a gap: one column, the full width.
    function test_a_narrow_page_gets_one() {
        const g = grid(500, 4);
        compare(g.columns, 1);
        compare(g.cellWidth, 500);
    }

    // One card across half a page reads as a card that failed to load its
    // neighbour.
    function test_a_single_card_takes_the_whole_width() {
        const g = grid(1200, 1);
        compare(g.columns, 1);
        compare(g.cellWidth, 1200);
    }

    // Two columns is the design; a very wide window does not become three.
    function test_it_never_goes_past_two() {
        compare(grid(3000, 9).columns, 2);
    }

    // A page is laid out once before it has been given a width. A column count
    // of zero there would divide the width by nothing and hand every card a
    // NaN, which draws as an empty page rather than as an error.
    function test_no_width_yet_is_one_column_and_not_a_nan() {
        const g = grid(0, 3);
        compare(g.columns, 1);
        compare(g.cellWidth, 0);
        verify(!isNaN(g.cellWidth));
    }

    // A card that is added before the model has loaded -- a page whose
    // sections arrive from the schema a moment later -- must not divide by
    // zero either.
    function test_no_cards_yet_is_one_column() {
        const g = grid(900, 0);
        compare(g.columns, 1);
        compare(g.cellWidth, 900);
    }
}
