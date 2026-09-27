// Tests for reading KDE's INI files.
//
// Every one of kdeglobals, plasmanotifyrc, kglobalshortcutsrc and
// plasmashellrc goes through this, for the colour scheme, do-not-disturb, the
// keys sheet and which launcher Plasma can open. A misread here is a panel in
// the wrong colours or a switch that says the wrong thing, with nothing in the
// journal to say why.

import QtQuick
import QtTest
import qs.core

TestCase {
    name: "Ini"

    readonly property string kdeglobals: `[$Version]
update_info=filepicker.upd:filepicker-remove-old-previews-entry

# a comment
[Colors:Window]
BackgroundNormal=239,240,241
ForegroundNormal = 35,38,41
DecorationFocus=61,174,233

[Colors:Window][Inactive]
BackgroundNormal=1,2,3

[General]
BrowserApplication=google-chrome.desktop
TerminalApplication=alacritty -e
broken-line

[Icons]
Theme=breeze-dark
`

    function test_groups_and_keys() {
        const g = Ini.parse(kdeglobals);
        compare(g["Colors:Window"].BackgroundNormal, "239,240,241");
        compare(g.General.TerminalApplication, "alacritty -e");
        compare(g.Icons.Theme, "breeze-dark");
    }

    // KDE's nested groups are groups of their own, named as written.
    function test_a_nested_group_is_its_own() {
        const g = Ini.parse(kdeglobals);
        compare(g["Colors:Window][Inactive"].BackgroundNormal, "1,2,3");
        compare(g["Colors:Window"].BackgroundNormal, "239,240,241");
    }

    function test_keys_and_values_are_trimmed() {
        compare(Ini.parse(kdeglobals)["Colors:Window"].ForegroundNormal, "35,38,41");
        compare(Ini.parse("[A]\n   k   =   v w   \n").A.k, "v w");
    }

    function test_comments_blank_lines_and_junk_are_skipped() {
        const g = Ini.parse("before=nothing\n[A]\n# k=commented\n\nno equals sign\nk=v\n");
        compare(g, { A: { k: "v" } });
    }

    // A whole file keeps the last of a key written twice, and a group written
    // twice is one group; a single key asked for is the first one written.
    function test_last_for_the_file_first_for_one_key() {
        const text = "[A]\nk=1\n[B]\nk=b\n[A]\nk=2\nother=x\n";
        compare(Ini.parse(text).A, { k: "2", other: "x" });
        compare(Ini.value(text, "A", "k"), "1");
    }

    function test_a_value_may_hold_an_equals_sign() {
        compare(Ini.parse("[A]\nexec=sh -c a=b\n").A.exec, "sh -c a=b");
        compare(Ini.value("[A]\nexec=sh -c a=b\n", "A", "exec"), "sh -c a=b");
    }

    function test_one_key_of_one_group() {
        compare(Ini.value(kdeglobals, "General", "TerminalApplication"), "alacritty -e");
        compare(Ini.value(kdeglobals, "Icons", "Theme"), "breeze-dark");
        // A key of another group is not this group's.
        compare(Ini.value(kdeglobals, "Icons", "TerminalApplication"), "");
        compare(Ini.value(kdeglobals, "Nothing", "Theme"), "");
        compare(Ini.value(kdeglobals, "Colors:Window][Inactive", "BackgroundNormal"), "1,2,3");
    }

    // plasmashellrc, as it is: the package is read from [Shell] alone.
    function test_the_shell_package() {
        const rc = "[PlasmaViews][Panel 7]\nfloating=1\n\n[Shell]\nShellPackage=org.kde.plasma.desktop\n";
        compare(Ini.value(rc, "Shell", "ShellPackage"), "org.kde.plasma.desktop");
        compare(Ini.value("[Other]\nShellPackage=x\n", "Shell", "ShellPackage"), "");
    }

    function test_nothing_in_nothing_out() {
        compare(Ini.parse(""), {});
        compare(Ini.parse(undefined), {});
        compare(Ini.value(undefined, "A", "k"), "");
        compare(Ini.value("[A]\n=v\n", "A", ""), "");
    }
}
