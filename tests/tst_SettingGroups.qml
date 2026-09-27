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

    // ---- set keys ----------------------------------------------------------
    //
    // Which tiles the quick settings draw is a `set`: a fixed list of members,
    // any of which may be on. The order they are stored in is the order they
    // are drawn in, which is why turning one off and on again must not move
    // it.

    readonly property var members: ["wifi", "ethernet", "bluetooth", "dnd"]

    function test_turning_one_off_leaves_the_rest_in_order() {
        const out = SettingGroups.chooseFrom(members, members, "bluetooth", false);
        compare(out, ["wifi", "ethernet", "dnd"]);
    }

    // The one that started this: an append would have put it last, and a tile
    // would wander down the grid every time it was switched.
    function test_turning_one_back_on_puts_it_where_the_schema_has_it() {
        const without = SettingGroups.chooseFrom(members, members, "ethernet", false);
        compare(SettingGroups.chooseFrom(members, without, "ethernet", true),
                ["wifi", "ethernet", "bluetooth", "dnd"]);
    }

    // Nothing stored means everything, so a fresh machine draws the lot.
    function test_no_stored_value_means_every_member() {
        compare(SettingGroups.chooseFrom(members, undefined, "dnd", false),
                ["wifi", "ethernet", "bluetooth"]);
    }

    // A member the stored list has never heard of -- the schema gained one
    // since it was written -- is off until it is asked for, and the ones that
    // were chosen keep their places.
    function test_a_member_the_stored_list_never_had_stays_out() {
        compare(SettingGroups.chooseFrom(members, ["wifi", "dnd"], "wifi", true),
                ["wifi", "dnd"]);
    }

    // Turning on something that is not a member of the set changes nothing:
    // the schema decides what the members are.
    function test_a_value_outside_the_set_is_not_added() {
        compare(SettingGroups.chooseFrom(members, ["wifi"], "vpn", true), ["wifi"]);
    }

    // ---- lists ----------------------------------------------------------

    function test_an_ordered_list_keeps_the_persons_order() {
        const cards = ["media", "day", "weather"];
        compare(SettingGroups.chooseInOrder(cards, ["weather", "media"], "day", true), ["weather", "media", "day"]);
        compare(SettingGroups.chooseInOrder(cards, ["weather", "media"], "weather", false), ["media"]);
    }

    function test_an_absent_ordered_list_is_all_of_them() {
        compare(SettingGroups.chooseInOrder(["a", "b"], undefined, "a", false), ["b"]);
    }

    function test_a_list_that_was_saved_as_text_is_mended_not_mapped() {
        // The old text field saved `"a,b"`; turning one on must not throw.
        compare(SettingGroups.chooseInOrder(["a", "b"], "a,b", "a", true), ["a", "b"]);
    }

    function test_items_split_on_commas() {
        compare(SettingGroups.parseList(" org.kde.dolphin, firefox ,,", "items"), ["org.kde.dolphin", "firefox"]);
        compare(SettingGroups.formatList(["a", "b"], "items"), "a, b");
        compare(SettingGroups.parseList("", "items"), []);
    }

    function test_a_command_splits_like_a_shell_would() {
        compare(SettingGroups.parseList(`fuzzel --prompt "run: " -w 40`, "words"), ["fuzzel", "--prompt", "run: ", "-w", "40"]);
        compare(SettingGroups.parseList(`a '' b`, "words"), ["a", "", "b"]);
    }

    function test_a_command_comes_back_as_it_went_in() {
        const argv = ["fuzzel", "--prompt", "run: ", ""];
        compare(SettingGroups.parseList(SettingGroups.formatList(argv, "words"), "words"), argv);
    }
}
