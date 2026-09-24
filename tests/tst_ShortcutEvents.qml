// Tests for the kglobalaccel signal parser.
//
// This is the part whose failure looks like "the key sometimes does nothing",
// or worse, "somebody else's key opened our launcher": every shell on the
// machine announces its shortcuts on this one interface, so the component name
// is the only thing keeping ours apart from theirs.

import QtQuick
import QtTest
import qs.domain.shortcuts.events
import "fixtures/bus.js" as Bus

TestCase {
    name: "ShortcutEvents"

    function line(member, data) {
        return Bus.signal("org.kde.kglobalaccel.Component", member, "ssx", data,
                          { sender: ":1.390", path: "/component/ours_shell" });
    }

    function test_pressed() {
        const e = ShortcutEvents.parse(line("globalShortcutPressed", ["ours-shell", "launcher", 0]),
                                       "ours-shell");
        verify(e !== null);
        compare(e.action, "launcher");
        compare(e.kind, "pressed");
    }

    function test_released() {
        const e = ShortcutEvents.parse(line("globalShortcutReleased", ["ours-shell", "switcher", 12]),
                                       "ours-shell");
        verify(e !== null);
        compare(e.action, "switcher");
        compare(e.kind, "released");
    }

    // A held Alt+Tab repeats. A repeat is the switcher already being up, not a
    // second request to open it, so it is not an event at all.
    function test_repeat_is_not_an_event() {
        compare(ShortcutEvents.parse(line("globalShortcutRepeated", ["ours-shell", "switcher", 0]),
                                     "ours-shell"), null);
    }

    // The one that matters most: another shell's keys go past on this same
    // interface, and must not be ours.
    function test_another_component() {
        compare(ShortcutEvents.parse(line("globalShortcutPressed", ["another-shell", "launcher", 0]),
                                     "ours-shell"), null);
    }

    function test_short_payload() {
        compare(ShortcutEvents.parse(line("globalShortcutPressed", ["ours-shell"]),
                                     "ours-shell"), null);
    }

    function test_empty_action() {
        compare(ShortcutEvents.parse(line("globalShortcutPressed", ["ours-shell", "", 0]),
                                     "ours-shell"), null);
    }

    function test_not_a_signal() {
        compare(ShortcutEvents.parse("", "ours-shell"), null);
        compare(ShortcutEvents.parse("not json", "ours-shell"), null);
    }

    // The path kglobalaccel keeps a component under. A dash is not a character
    // D-Bus will have in an object path.
    function test_path_for() {
        compare(ShortcutEvents.pathFor("ours-shell"), "/component/ours_shell");
        compare(ShortcutEvents.pathFor("org.kde.thing"), "/component/org_kde_thing");
    }
}
