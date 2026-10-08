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
}
