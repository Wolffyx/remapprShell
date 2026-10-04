import QtQuick
import QtTest
import qs.domain.sidebar.cards

TestCase {
    name: "Cards"

    function test_the_order_is_the_settings_order() {
        compare(Cards.order(["weather", "media"]).map(c => c.id), ["weather", "media"]);
        // A card this version does not have is left out rather than leaving a
        // gap, which is what a downgrade would otherwise do to a sidebar.
        compare(Cards.order(["media", "horoscope"]).map(c => c.id), ["media"]);
        // Nothing listed is every card: a sidebar with none is never what was
        // meant.
        compare(Cards.order([]).length, Cards.all.length);
        compare(Cards.order(undefined).length, Cards.all.length);
    }

    function test_folding_a_card_returns_a_new_list() {
        const open = ["media"];
        compare(Cards.isOpen(open, "media"), true);
        compare(Cards.isOpen(open, "weather"), false);
        compare(Cards.toggled(open, "weather"), ["media", "weather"]);
        compare(Cards.toggled(open, "media"), []);
        // The list handed in is not touched: it is a setting, and a value
        // mutated in place is a value nothing notices changing.
        compare(open, ["media"]);
        compare(Cards.toggled(undefined, "day"), ["day"]);
    }

    function test_the_side_decides_the_edge() {
        compare(Cards.onLeft("left"), true);
        compare(Cards.onLeft("right"), false);
        compare(Cards.onLeft(undefined), false);
        compare(Cards.edgeFor("left"), "Left");
        compare(Cards.edgeFor("right"), "Right");
    }

    // This machine's layout: a landscape screen with a portrait one to its
    // right, taller than it and reaching above it.
    readonly property var dp2: ({ name: "DP-2", x: 0, y: 1040, width: 2560, height: 1440 })
    readonly property var dp3: ({ name: "DP-3", x: 2560, y: 0, width: 1440, height: 2560 })

    function test_an_edge_another_screen_meets_is_not_outer() {
        const both = [dp2, dp3];
        // DP-2's right edge is DP-3's left, every pixel of it.
        compare(Cards.edgeIsOuter(dp2, both, false), false);
        compare(Cards.edgeIsOuter(dp3, both, true), false);
        // The far sides are the layout's own.
        compare(Cards.edgeIsOuter(dp3, both, false), true);
        compare(Cards.edgeIsOuter(dp2, both, true), true);
    }

    function test_screens_that_only_touch_at_a_corner_do_not_share_an_edge() {
        const below = { name: "B", x: 2560, y: 2480, width: 1440, height: 900 };
        compare(Cards.edgeIsOuter(dp2, [dp2, below], false), true);
        // Overlapping by one pixel row is sharing.
        const lower = { name: "L", x: 2560, y: 2479, width: 1440, height: 900 };
        compare(Cards.edgeIsOuter(dp2, [dp2, lower], false), false);
    }

    function test_one_screen_has_only_outer_edges() {
        compare(Cards.edgeIsOuter(dp2, [dp2], false), true);
        compare(Cards.edgeIsOuter(dp2, [], true), true);
        compare(Cards.edgeIsOuter(null, [dp2], true), false);
    }
}
