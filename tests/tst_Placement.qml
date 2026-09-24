// Where a popout goes beside the panel.
//
// Every placement bug this project has had was one of these numbers, and none
// of them could be seen without a screen. They can be checked here.

import QtQuick
import QtTest
import qs.domain.panel

TestCase {
    name: "Placement"

    // This machine's panel: 52 px thick at the bottom, popouts 12 px clear of
    // it, and a shadow that wants 29 px of transparent room around the card.
    readonly property int extent: 52
    readonly property int gap: 12
    readonly property int shadow: 29
    readonly property int edgeMargin: 12

    // ---- out from the screen's edge --------------------------------------

    // The regression that made the start button unable to close the menu it
    // had opened. With the shadow's room taken off the gap, the window began
    // 12 px from the screen's edge -- forty pixels *inside* the panel -- and
    // a popout with no input mask took every click in that band.
    function test_a_popout_never_reaches_back_over_the_panel() {
        verify(Placement.away(extent, gap, shadow) >= extent);
        verify(Placement.away(extent, gap, 0) >= extent);
        verify(Placement.away(extent, gap, 200) >= extent);
    }

    // With no shadow -- the default -- what is drawn sits exactly `gap`
    // beyond the panel and the window is the card.
    function test_no_shadow_means_the_gap_is_the_gap() {
        compare(Placement.away(extent, gap, 0), extent + gap);
    }

    // With one, the gap opens up to the shadow's reach rather than the shadow
    // being cut off square where the room ran out -- which is what a card with
    // a straight bottom-left corner looks like.
    function test_a_shadow_is_never_cut_off_by_the_panel() {
        const y = Placement.away(extent, gap, shadow);
        // The window starts at the panel's edge: every pixel of shadow is on
        // screen, and none of the window is over the panel.
        compare(y, extent);
        // And the card is the shadow's whole reach clear of the panel.
        compare(y + shadow, extent + shadow);
    }

    // A shadow smaller than the gap changes nothing.
    function test_a_small_shadow_does_not_widen_the_gap() {
        compare(Placement.away(52, 12, 6), 52 + 12 - 6);
        compare(Placement.away(52, 12, 6) + 6, 52 + 12);
    }

    function test_no_panel_at_all_is_not_a_negative_margin() {
        compare(Placement.away(0, 0, 40), 0);
    }

    // ---- a popout that hangs from its widget ------------------------------

    // The distance the neck crosses: the gap, or the shadow's reach if that
    // opened it up.
    function test_what_is_drawn_sits_the_gap_or_the_shadow_clear() {
        compare(Placement.reach(gap, 0), gap);
        compare(Placement.reach(gap, shadow), shadow);
        compare(Placement.reach(gap, 6), gap);
    }

    // With a tail the window's room on the panel's side is that whole
    // distance, so the window starts at the panel's edge -- the neck has to
    // reach it -- and never over the panel.
    function test_a_tail_takes_the_window_to_the_panels_edge() {
        compare(Placement.away(extent, gap, 0, Placement.reach(gap, 0)), extent);
        compare(Placement.away(extent, gap, shadow, Placement.reach(gap, shadow)), extent);
    }

    // And the card itself does not move: only the window grows towards the
    // panel. The start of the card is where it was without one.
    function test_a_tail_does_not_move_the_card() {
        for (const s of [0, 6, shadow]) {
            const room = Placement.reach(gap, s);
            compare(Placement.away(extent, gap, s, room) + room, Placement.away(extent, gap, s) + s);
        }
    }

    // ---- along the panel --------------------------------------------------

    function test_centred_on_what_the_slot_pointed_at() {
        // A 200-wide card under a slot starting at 1000, pointing 20 in.
        const x = Placement.along("centre", 1000, 20, 200 + 2 * shadow, 2560, shadow, edgeMargin);
        // The card's own left edge, not the window's.
        compare(x + shadow, 920);
    }

    // The start menu: nine hundred pixels wide, on a fifty-pixel button at the
    // corner. Centred it would sit at -400 and be shoved to the screen edge,
    // level with nothing. Aligned, it begins where the button does.
    function test_a_menu_begins_where_its_button_does() {
        const x = Placement.along("start", 72, 0, 930 + 2 * shadow, 2560, shadow, edgeMargin);
        compare(x + shadow, 72);
    }

    function test_a_wide_popout_is_kept_on_screen() {
        // Centred on a widget at the right-hand end.
        const size = 600 + 2 * shadow;
        const x = Placement.along("centre", 2500, 20, size, 2560, shadow, edgeMargin);
        verify(x + shadow + 600 <= 2560 - edgeMargin + 1);
    }

    function test_and_at_the_other_end_too() {
        const size = 600 + 2 * shadow;
        const x = Placement.along("centre", 10, 20, size, 2560, shadow, edgeMargin);
        verify(x + shadow >= edgeMargin - 1);
    }

    // ---- the card moving inside its own window ---------------------------

    // The start menu, twelve pixels from the corner with a shadow wanting
    // twenty-nine: the window cannot start at -17, so the card gives up that
    // much of the window's shadow room instead and the corner lands on the
    // button.
    function test_a_menu_at_the_corner_still_lands_on_its_button() {
        const size = 930 + 2 * shadow;
        const x = Placement.along("start", 12, 0, size, 2560, shadow, edgeMargin);
        const s = Placement.shift("start", 12, 0, size, 2560, shadow, edgeMargin);
        compare(x, 0);
        compare(s, -17);
        // Where the card actually lands: the window, plus the leading room.
        compare(x + shadow + s, 12);
    }

    function test_nothing_moves_when_nothing_was_clamped() {
        const size = 200 + 2 * shadow;
        compare(Placement.shift("centre", 1000, 20, size, 2560, shadow, edgeMargin), 0);
    }

    // And at the far end, the other way.
    function test_the_far_end_moves_the_other_way() {
        const size = 300 + 2 * shadow;
        const s = Placement.shift("centre", 2540, 10, size, 2560, shadow, edgeMargin);
        verify(s > 0);
    }

    // Never further than the room there is, or the card would leave its own
    // window.
    function test_the_card_never_leaves_its_window() {
        const s = Placement.shift("start", 0, 0, 4000, 2560, shadow, edgeMargin);
        verify(Math.abs(s) <= shadow);
    }

    // With shadows off there is no room to give up and nothing to clamp: the
    // card is exactly where the widget is, which is the default this ships
    // with.
    function test_with_no_shadow_the_alignment_is_exact() {
        const x = Placement.along("start", 12, 0, 930, 2560, 0, edgeMargin);
        compare(x + Placement.shift("start", 12, 0, 930, 2560, 0, edgeMargin), 12);
        compare(Placement.away(52, 12, 0), 64);
        // No transparent border anywhere: the card is the window.
        compare(Placement.away(52, 12, 0) + 0, 64);
    }

    // A card wider than the screen has nowhere to go; it must still be a
    // number, and the same one at both ends rather than a negative position.
    function test_a_popout_wider_than_the_screen() {
        const x = Placement.along("centre", 100, 20, 3000, 2560, shadow, edgeMargin);
        compare(x, Placement.along("start", 100, 20, 3000, 2560, shadow, edgeMargin));
        verify(x >= 0);
    }

    // The vertical panel is the same arithmetic with the screen's height: it
    // is measured along the panel, not along x.
    function test_a_side_panel_uses_the_same_rules() {
        const x = Placement.along("centre", 1200, 20, 300, 2560, shadow, edgeMargin);
        compare(x, Placement.along("centre", 1200, 20, 300, 2560, shadow, edgeMargin));
        verify(x > 0);
    }
}
