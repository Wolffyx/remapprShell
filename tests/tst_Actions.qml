// Tests for the launcher's actions and its calculator.

import QtQuick
import QtTest
import qs.domain.launcher.actions

TestCase {
    name: "Actions"

    function test_the_prefix_turns_on_actions() {
        compare(Actions.parse(">scheme", ">"), { actions: true, text: "scheme" });
        compare(Actions.parse(": dark", ":"), { actions: true, text: "dark" });
        compare(Actions.parse("firefox", ">"), { actions: false, text: "firefox" });
        compare(Actions.parse("/lock", ">"), { actions: false, text: "/lock" });
    }

    function test_every_action_for_nothing_typed() {
        compare(Actions.match("").length, Actions.all.length);
    }

    function test_best_match_first() {
        const m = Actions.match("dark");
        compare(m[0].id, "dark");
        verify(m.some(a => a.id === "scheme"), "a keyword finds the scheme too");
        compare(Actions.match("sh")[0].id, "shutdown");
        compare(Actions.match("zzz").length, 0);
    }

    function test_arithmetic() {
        compare(Actions.evaluate("2+2"), 4);
        compare(Actions.evaluate("2 + 3 * 4"), 14);
        compare(Actions.evaluate("(2+3)*4"), 20);
        compare(Actions.evaluate("-2^2"), -4);
        compare(Actions.evaluate("2^3^2"), 512);
        compare(Actions.evaluate("7 % 3"), 1);
        compare(Actions.evaluate("1,5*2"), 3);
        compare(Actions.evaluate("12×7"), 84);
        compare(Actions.evaluate(".5+.25"), 0.75);
    }

    // Anything that is not arithmetic is refused, not run.
    function test_nothing_else_is_evaluated() {
        compare(Actions.evaluate("alert(1)"), null);
        compare(Actions.evaluate("2+"), null);
        compare(Actions.evaluate("(2"), null);
        compare(Actions.evaluate(""), null);
        compare(Actions.evaluate("1/0"), null);
        compare(Actions.evaluate("Math.PI"), null);
    }

    function test_a_number_alone_is_not_a_sum() {
        verify(Actions.isSum("12*7"));
        verify(Actions.isSum("(1+2)/3"));
        verify(!Actions.isSum("42"));
        verify(!Actions.isSum("firefox"));
    }

    function test_format() {
        compare(Actions.formatNumber(84), "84");
        compare(Actions.formatNumber(0.1 + 0.2), "0.3");
        compare(Actions.formatNumber(1 / 3), "0.333333333333");
    }
}
