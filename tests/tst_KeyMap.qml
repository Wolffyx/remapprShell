// Tests for reading what the keys do out of kglobalshortcutsrc.

import QtQuick
import QtTest
import qs.domain.keys

TestCase {
    name: "KeyMap"

    readonly property string file: "[ksmserver]\n"
        + "Lock Session=Screensaver\\tMeta+L,Screensaver\\tMeta+L,Lock Session\n"
        + "Log Out=none,Ctrl+Alt+Del,Show Logout Screen\n"
        + "\n[kwin]\n"
        + "Overview=Meta+W,Meta+W,Toggle Overview\n"
        + "Grid View=none,Meta+G,Toggle Grid View\n"
        + "Window Close=Alt+F4,Alt+F4,Close Window\n"
        + "Window Maximize=Meta+PgUp,Meta+PgUp,Maximize Window\n"
        + "\n[services][org.kde.krunner.desktop]\n"
        + "_launch=Alt+Space,Alt+Space,KRunner\n"
        + "\n[services][testshell-settings.desktop]\n"
        + "_launch=Meta+Shift+R, , Settings\n"
        + "\n[services][testshell-clipboard.desktop]\n"
        + "_launch=none\n"

    function test_parse_keeps_the_current_keys() {
        const m = KeyMap.parse(file);
        compare(m.kwin.Overview.keys, ["Meta+W"]);
        compare(m.kwin.Overview.label, "Toggle Overview");
        compare(m.ksmserver["Lock Session"].keys, ["Screensaver", "Meta+L"]);
    }

    // "none" is not a key: the default is what it would be, not what it is.
    function test_none_is_unbound() {
        const m = KeyMap.parse(file);
        compare(m.kwin["Grid View"].keys, []);
        compare(m.ksmserver["Log Out"].keys, []);
    }

    // Read the way every KDE file here is read (see Ini): a key is trimmed,
    // so a hand-edited line with spaces round the "=" is still that action.
    function test_a_key_is_read_trimmed() {
        const m = KeyMap.parse("[kwin]\nOverview = Meta+W,Meta+W,Toggle Overview\n");
        compare(m.kwin.Overview.keys, ["Meta+W"]);
        compare(m.kwin.Overview.label, "Toggle Overview");
    }

    function test_keys_of_something_missing() {
        compare(KeyMap.keysOf(KeyMap.parse(file), "kwin", "Nothing"), []);
        compare(KeyMap.keysOf({}, "kwin", "Overview"), []);
    }

    function test_sections_leave_out_what_is_not_bound() {
        const s = KeyMap.sections(KeyMap.parse(file), "testshell");
        compare(s.length, 2);
        compare(s[0].title, "Shell");
        const labels = s[0].rows.map(r => r.label);
        verify(labels.indexOf("Search") >= 0);
        verify(labels.indexOf("Overview") >= 0);
        verify(labels.indexOf("Lock") >= 0);
        verify(labels.indexOf("Virtual desktops") < 0, "Grid View is none");
        verify(labels.indexOf("Log out") < 0, "Log Out is none");
        compare(s[1].rows.map(r => r.label), ["Close the window", "Maximise"]);
    }

    function test_the_shells_own_keys_are_listed() {
        const rows = KeyMap.shellRows(KeyMap.parse(file), "testshell");
        compare(rows.length, 1);
        compare(rows[0].keys, ["Meta+Shift+R"]);
        compare(rows[0].label, "Settings");
    }

    function test_an_empty_file_has_nothing() {
        compare(KeyMap.sections(KeyMap.parse(""), "testshell").length, 0);
    }
}
