// Tests for the status glyphs as one button or one widget each: the change
// the Taskbar page's "Status icons" switch makes to `bar.entries`.

import QtQuick
import QtTest
import qs.domain.panel

TestCase {
    name: "StatusGroup"

    function ids(list) {
        return list.map(e => e.id);
    }

    readonly property var separateBar: [
        { id: "launcher", zone: "left", enabled: true },
        { id: "tray", zone: "right", enabled: true },
        { id: "privacy", zone: "right", enabled: true },
        { id: "network", zone: "right", enabled: true },
        { id: "volume", zone: "right", enabled: true },
        { id: "battery", zone: "right", enabled: true },
        { id: "clock", zone: "right", enabled: true }
    ]

    // The button goes where the first glyph was, holding them in order;
    // privacy stays a widget of its own.
    function test_group_keeps_the_place() {
        const r = StatusGroup.group(separateBar);
        compare(ids(r.entries), ["launcher", "tray", "privacy", "status", "clock"]);
        compare(r.parts, ["network", "volume", "battery"]);
        compare(r.entries[3].zone, "right");
        verify(StatusGroup.grouped(r.entries));
    }

    // Nothing to group: the button is added at the end, with the default
    // glyphs.
    function test_group_with_nothing_to_group() {
        const r = StatusGroup.group([{ id: "clock", zone: "middle", enabled: true }]);
        compare(ids(r.entries), ["clock", "status"]);
        compare(r.parts, StatusGroup.defaultParts);
    }

    // A disabled widget is not one of the glyphs, and is left where it is.
    function test_group_skips_disabled() {
        const r = StatusGroup.group([{ id: "network", zone: "right", enabled: false },
                                     { id: "volume", zone: "right", enabled: true }]);
        compare(ids(r.entries), ["network", "status"]);
        compare(r.parts, ["volume"]);
    }

    function test_group_twice_changes_nothing() {
        const once = StatusGroup.group(separateBar).entries;
        const twice = StatusGroup.group(once);
        compare(ids(twice.entries), ids(once));
        compare(twice.parts, null);
    }

    // Separating puts the widgets back where the button was, in its order.
    function test_separate_puts_them_back() {
        const r = StatusGroup.group(separateBar);
        const back = StatusGroup.separate(r.entries, r.parts);
        compare(ids(back), ids(separateBar));
        verify(!StatusGroup.grouped(back));
    }

    // One already on the panel is not added twice; anything that is not a
    // glyph widget is not added at all.
    function test_separate_skips_what_is_there() {
        const bar = [{ id: "volume", zone: "right", enabled: true }, { id: "status", zone: "right", enabled: true }];
        compare(ids(StatusGroup.separate(bar, ["volume", "battery", "privacy", "nonsense"])), ["volume", "battery"]);
    }

    function test_separate_without_a_button() {
        compare(ids(StatusGroup.separate(separateBar, ["network"])), ids(separateBar));
        compare(ids(StatusGroup.separate([{ id: "status", zone: "right" }], undefined)), StatusGroup.defaultParts);
    }
}
