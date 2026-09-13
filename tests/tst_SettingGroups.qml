// Tests for how a section's keys become the cards on a settings page.
//
// Every one of these rules is invisible in the code and obvious on screen: a
// page whose cards come in an order nobody chose, a card with no heading
// sitting beside headed ones, or -- the one that started this -- a settings
// page that silently loses a key because its group was spelled differently
// somewhere else. So they are pinned here rather than found by looking.

import QtQuick
import QtTest
import qs.domain.settings.groups

TestCase {
    name: "SettingGroups"

    function spec(group) {
        return group === undefined ? ({}) : ({ group: group });
    }

    // The ordinary case, and the one every page had before there were groups:
    // no key names a group, so the whole section is one card under its own
    // name.
    function test_keys_with_no_group_are_one_card_titled_by_the_section() {
        const out = SettingGroups.split({ "a.one": spec(), "a.two": spec() }, "Desktop");
        compare(out.length, 1);
        compare(out[0].label, "Desktop");
        compare(out[0].keys, ["a.one", "a.two"]);
    }

    // A card keeps the place of its first key. Grouping by filtering instead
    // would order the page by the code rather than by the schema.
    function test_cards_come_in_the_order_the_schema_reads_in() {
        const out = SettingGroups.split({
            "a.border":  spec("Screen border"),
            "a.clock":   spec("Desktop clock"),
            "a.inset":   spec("Screen border"),
            "a.size":    spec("Desktop clock")
        }, "Desktop");

        compare(out.length, 2);
        compare(out[0].label, "Screen border");
        compare(out[0].keys, ["a.border", "a.inset"]);
        compare(out[1].label, "Desktop clock");
        compare(out[1].keys, ["a.clock", "a.size"]);
    }

    // The section's own settings are its subject, so they stay at the top even
    // when a group is named before them.
    function test_the_ungrouped_card_comes_first_wherever_its_keys_are() {
        const out = SettingGroups.split({
            "a.grouped": spec("Later"),
            "a.plain":   spec()
        }, "Section");

        compare(out.length, 2);
        compare(out[0].label, "Later");
        compare(out[1].label, "Section");
        compare(out[1].keys, ["a.plain"]);
    }

    // An empty group is no group, not a card named "".
    function test_an_empty_group_is_the_same_as_none() {
        const out = SettingGroups.split({ "a.one": spec(""), "a.two": spec() }, "Section");
        compare(out.length, 1);
        compare(out[0].keys, ["a.one", "a.two"]);
    }

    // A page that would rather not repeat its own heading passes no title, and
    // must get a card with no label rather than the string "undefined".
    function test_no_title_leaves_the_first_card_unlabelled() {
        const out = SettingGroups.split({ "a.one": spec() }, undefined);
        compare(out.length, 1);
        compare(out[0].label, "");
    }

    // A section that is only a page -- windows, tray, presets -- has no keys
    // at all, and must draw nothing rather than an empty card.
    function test_nothing_at_all_is_no_cards() {
        compare(SettingGroups.split({}, "Section").length, 0);
        compare(SettingGroups.split(null, "Section").length, 0);
        compare(SettingGroups.split(undefined, "Section").length, 0);
    }
}
