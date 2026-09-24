// Tests for the scope every application is started in (AppScope, which
// Launch runs everything through).
//
// On 2026-09-24 a restart of the shell took the user's game and Steam with
// it, because both had been started as the shell's children. The name is
// what has to be right for the cure to work at all: a unit name systemd
// refuses is an application that never starts, and says so only on a stderr
// nobody reads. The expected escapes are what `systemd-escape` itself prints
// for the same strings.

import QtQuick
import QtTest
import qs.core

TestCase {
    name: "Launch"

    function test_escape_like_systemd_escape() {
        compare(AppScope.escaped("org.kde.dolphin"), "org.kde.dolphin");
        compare(AppScope.escaped("steam"), "steam");
        compare(AppScope.escaped("a:b_c.d"), "a:b_c.d");
        compare(AppScope.escaped("UPPER09"), "UPPER09");
        compare(AppScope.escaped(""), "");
    }

    // A dash inside a part is escaped, so the dashes left are the separators
    // between the launcher, the application and the random part.
    function test_escape_dashes() {
        compare(AppScope.escaped("org.kde.plasma-systemmonitor"), "org.kde.plasma\\x2dsystemmonitor");
        compare(AppScope.escaped("my-shell"), "my\\x2dshell");
    }

    function test_escape_what_a_unit_name_may_not_hold() {
        compare(AppScope.escaped("Open my notes"), "Open\\x20my\\x20notes");
        compare(AppScope.escaped("FOO=bar"), "FOO\\x3dbar");
        compare(AppScope.escaped("a\\b"), "a\\x5cb");
        compare(AppScope.escaped("x/y"), "x-y");
    }

    function test_escape_a_leading_dot_only() {
        compare(AppScope.escaped(".a.b"), "\\x2ea.b");
    }

    // Byte by byte, as UTF-8: a name in any language, and one outside the
    // Basic Multilingual Plane, which JavaScript holds as two halves.
    function test_escape_utf8() {
        compare(AppScope.escaped("日本"), "\\xe6\\x97\\xa5\\xe6\\x9c\\xac");
        compare(AppScope.escaped("ü"), "\\xc3\\xbc");
        compare(AppScope.escaped("😀"), "\\xf0\\x9f\\x98\\x80");
    }

    function test_unit_name() {
        compare(AppScope.unitName("my-shell", "org.kde.dolphin", "0123abcd"),
                "app-my\\x2dshell-org.kde.dolphin-0123abcd.scope");
        compare(AppScope.unitName("my-shell", "org.kde.plasma-systemmonitor", "ff"),
                "app-my\\x2dshell-org.kde.plasma\\x2dsystemmonitor-ff.scope");
    }

    // Too long and systemd refuses the name, so the application id gives way
    // -- and never through the middle of an escape.
    function test_unit_name_fits() {
        const long = AppScope.unitName("my-shell", "x".repeat(400), "0123456789abcdef");
        compare(long.length, AppScope.nameMax);
        verify(long.endsWith("-0123456789abcdef.scope"));

        for (let pad = 0; pad < 4; pad++) {
            const name = AppScope.unitName("my-shell", "y".repeat(pad) + "-".repeat(200), "0123456789abcdef");
            verify(name.length <= AppScope.nameMax, name);
            const id = name.slice("app-my\\x2dshell-".length, name.length - "-0123456789abcdef.scope".length);
            verify(/^y*(\\x2d)*$/.test(id), id);
        }
    }

    function test_id_of_a_command() {
        compare(AppScope.idOf(["/usr/bin/fuzzel", "--prompt", "run: "]), "fuzzel");
        compare(AppScope.idOf(["walker"]), "walker");
        compare(AppScope.idOf([]), "");
        compare(AppScope.idOf(undefined), "");
    }

    // The argv is the application's, untouched, after the `--`: an argument
    // that looks like an option of systemd-run's is still the application's.
    function test_wrap() {
        compare(AppScope.wrap(["sleep", "1"], "app-s-remapprtest-1.scope"),
                ["systemd-run", "--user", "--scope", "--slice=app.slice", "--collect", "--quiet",
                 "--unit=app-s-remapprtest-1.scope", "--", "sleep", "1"]);
        compare(AppScope.wrap(["prog", "--unit=x", "--", "%U"], "u.scope").slice(7),
                ["--", "prog", "--unit=x", "--", "%U"]);
        compare(AppScope.wrap([1, true], "u.scope").slice(8), ["1", "true"]);
    }
}
