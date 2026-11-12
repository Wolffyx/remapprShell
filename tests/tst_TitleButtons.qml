// The title-bar buttons' arithmetic: KWin's letters read and written, what
// each choice shows, and the custom editor's moves -- crossing to the other
// side at the end of a row, Other side, Hide, and a hidden button added.

import QtQuick
import QtTest
import qs.domain.windows.titlebar

TestCase {
    name: "TitleButtons"

    function st(left, right, side, code) {
        return { left: TitleButtons.split(left), right: TitleButtons.split(right),
                 sel: code ? { side: side, code: code } : null };
    }

    // "left|right", and the selection after it when there is one.
    function shown(state) {
        const sides = `${TitleButtons.letters(state.left)}|${TitleButtons.letters(state.right)}`;
        return state.sel ? `${sides} ${state.sel.side}:${state.sel.code}` : sides;
    }

    function test_letters_are_kwins_each_once() {
        compare(TitleButtons.split("XIA").join(","), "X,I,A");
        compare(TitleButtons.split("XQIX_a").join(","), "X,I");
        compare(TitleButtons.split("").length, 0);
        compare(TitleButtons.split(undefined).length, 0);
        compare(TitleButtons.letters(["M", "S"]), "MS");
    }

    function test_each_choice_shows_its_order() {
        const custom = { left: "XA", right: "F" };
        const kwin = { left: "MS", right: "HIAX" };
        compare(shown(TitleButtons.sidesOf("right", custom, kwin)), "|IAX");
        compare(shown(TitleButtons.sidesOf("left", custom, kwin)), "XIA|");
        compare(shown(TitleButtons.sidesOf("custom", custom, kwin)), "XA|F");
        compare(shown(TitleButtons.sidesOf("plasma", custom, kwin)), "MS|HIAX");
    }

    function test_the_fixed_orders_are_not_shared() {
        const a = TitleButtons.sidesOf("left", null, null);
        a.left.push("M");
        compare(shown(TitleButtons.sidesOf("left", null, null)), "XIA|");
    }

    function test_what_kwin_is_told() {
        compare(TitleButtons.line("plasma", st("MS", "HIAX")), "Nothing written");
        compare(TitleButtons.line("left", st("XIA", "")), "ButtonsOnLeft=XIA   ButtonsOnRight=");
    }

    function test_hidden_buttons_in_kwins_order() {
        compare(TitleButtons.pool(st("XIA", "")).join(""), "MSHFBL");
        compare(TitleButtons.pool(st("MSHIAX", "FBL")).length, 0);
    }

    function test_picking_selects_and_picking_again_lets_go() {
        const s = TitleButtons.pick(st("XIA", ""), "left", "I");
        compare(shown(s), "XIA| left:I");
        compare(shown(TitleButtons.pick(s, "left", "I")), "XIA|");
        compare(shown(TitleButtons.pick(s, "left", "A")), "XIA| left:A");
    }

    function test_moving_along_a_side() {
        compare(shown(TitleButtons.moveBack(st("XIA", "", "left", "I"))), "IXA| left:I");
        compare(shown(TitleButtons.moveOn(st("XIA", "", "left", "I"))), "XAI| left:I");
        compare(shown(TitleButtons.moveOn(st("", "IAX", "right", "I"))), "|AIX right:I");
    }

    function test_the_end_of_a_row_crosses_to_the_other_side() {
        compare(shown(TitleButtons.moveOn(st("XIA", "", "left", "A"))), "XI|A right:A");
        compare(shown(TitleButtons.moveBack(st("", "IAX", "right", "I"))), "I|AX left:I");
    }

    function test_the_outer_edges_go_nowhere() {
        const atLeft = st("XIA", "H", "left", "X");
        compare(TitleButtons.moveBack(atLeft), atLeft);
        const atRight = st("M", "IAX", "right", "X");
        compare(TitleButtons.moveOn(atRight), atRight);
    }

    function test_other_side_goes_to_the_end_of_the_row() {
        compare(shown(TitleButtons.otherSide(st("XIA", "H", "left", "X"))), "IA|HX right:X");
        compare(shown(TitleButtons.otherSide(st("M", "IAX", "right", "I"))), "MI|AX left:I");
    }

    function test_hide_takes_it_off_and_lets_go() {
        const s = TitleButtons.hide(st("XIA", "", "left", "I"));
        compare(shown(s), "XA|");
        verify(TitleButtons.pool(s).indexOf("I") >= 0);
    }

    function test_a_hidden_button_is_added_on_the_right_and_selected() {
        compare(shown(TitleButtons.add(st("XIA", ""), "F")), "XIA|F right:F");
        compare(shown(TitleButtons.add(st("XIA", "F"), "B")), "XIA|FB right:B");
    }

    function test_a_button_already_shown_is_not_added_twice() {
        const s = st("XIA", "");
        compare(TitleButtons.add(s, "X"), s);
        compare(TitleButtons.add(s, "Q"), s);
    }

    function test_nothing_selected_moves_nothing() {
        const s = st("XIA", "");
        compare(TitleButtons.moveBack(s), s);
        compare(TitleButtons.moveOn(s), s);
        compare(TitleButtons.otherSide(s), s);
        compare(TitleButtons.hide(s), s);
    }

    function test_a_move_leaves_the_state_it_was_given_alone() {
        const s = st("XIA", "", "left", "A");
        TitleButtons.moveOn(s);
        TitleButtons.otherSide(s);
        TitleButtons.hide(s);
        compare(shown(s), "XIA| left:A");
    }
}
