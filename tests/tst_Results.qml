// Tests for putting the search's several sources into one readable list.

import QtQuick
import QtTest
import qs.domain.launcher.apps

TestCase {
    name: "Results"

    function c(group, name, score) {
        return { item: { kind: group, name: name }, score: score, group: group };
    }

    function names(list) {
        return list.map(r => r.name).join(",");
    }

    function groups(list) {
        return list.map(r => r.group).join(",");
    }

    function test_score_decides_what_is_in_the_list() {
        const merged = Results.merge([
            c("app", "Weak", 100),
            c("window", "Strong", 900),
            c("file", "Middling", 500)
        ], 2);
        compare(merged.length, 2);
        compare(names(merged).includes("Weak"), false);
    }

    function test_groups_decide_the_order() {
        // The window scores highest and is still drawn under the application:
        // score decides what is present, the group decides where it sits.
        const merged = Results.merge([
            c("window", "Strong", 900),
            c("app", "Weak", 100),
            c("setting", "Middling", 500)
        ], 8);
        compare(groups(merged), "app,window,setting");
    }

    function test_score_order_is_kept_inside_a_group() {
        const merged = Results.merge([
            c("app", "Third", 100),
            c("app", "First", 900),
            c("app", "Second", 500)
        ], 8);
        compare(names(merged), "First,Second,Third");
    }

    function test_applications_are_never_capped() {
        // "termina" is a query whose whole answer is a list of terminals.
        const many = [];
        for (let i = 0; i < 12; i++)
            many.push(c("app", `Terminal ${i}`, 900 - i));

        const merged = Results.merge(many, 8);
        compare(merged.length, 8);
        compare(merged.filter(r => r.group === "app").length, 8);
    }

    function test_no_secondary_source_can_fill_the_card() {
        const many = [];
        for (let i = 0; i < 20; i++)
            many.push(c("window", `Window ${i}`, 900 - i));
        many.push(c("app", "An application", 100));

        const merged = Results.merge(many, 8);
        compare(merged.filter(r => r.group === "window").length, Results.perGroup);
        // ... and the application, which every window outscored, survives.
        compare(merged.filter(r => r.group === "app").length, 1);
    }

    function test_a_pin_comes_first_whatever_it_scored() {
        // The case a bonus could not reach: a pinned editor matched on its
        // generic name, under three applications with "Editor" in the name.
        const merged = Results.merge([
            c("app", "Menu Editor", 7000),
            c("app", "Kwave Sound Editor", 7000),
            Object.assign(c("app", "Kate", 3000), { pinned: true })
        ], 8);
        compare(names(merged).split(",")[0], "Kate");
    }

    function test_two_pins_are_still_ordered_by_score() {
        const merged = Results.merge([
            Object.assign(c("app", "Weaker", 3000), { pinned: true }),
            Object.assign(c("app", "Stronger", 7000), { pinned: true }),
            c("app", "Unpinned", 8000)
        ], 8);
        compare(names(merged), "Stronger,Weaker,Unpinned");
    }

    function test_equal_scores_do_not_wobble() {
        const a = Results.merge([c("app", "Beta", 500), c("app", "Alpha", 500)], 8);
        const b = Results.merge([c("app", "Alpha", 500), c("app", "Beta", 500)], 8);
        compare(names(a), names(b));
        compare(names(a), "Alpha,Beta");
    }

    function test_nothing_in_nothing_out() {
        compare(Results.merge([], 8).length, 0);
        compare(Results.merge(undefined, 8).length, 0);
    }

    function test_a_heading_appears_once_per_run() {
        const merged = Results.merge([
            c("app", "One", 900), c("app", "Two", 800), c("window", "Three", 700)
        ], 8);
        compare(Results.headingAt(merged, 0), "Applications");
        compare(Results.headingAt(merged, 1), "");
        compare(Results.headingAt(merged, 2), "Open windows");
    }

    function test_a_row_with_no_group_has_no_heading() {
        compare(Results.headingAt([{ name: "x" }], 0), "");
        compare(Results.headingAt([], 0), "");
    }
}
