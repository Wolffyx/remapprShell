// Tests for the schema migrations' steps (MigrationSteps).
//
// A step rewrites somebody's profile the first time a new build reads it, and
// the profile is written back straight after -- so a step that loses a choice
// loses it for good, with a line in the journal that says the migration went
// well.

import QtQuick
import QtTest
import qs.domain.config.steps

TestCase {
    name: "Migrations"

    // 2: fuzzel and rofi were launchers of their own, and are the custom
    // command now, running what they ran.
    function test_2_fuzzel_becomes_the_custom_command() {
        compare(MigrationSteps.toVersion2({ launcher: { provider: "fuzzel" } }),
                { launcher: { provider: "custom", command: ["fuzzel"] } });
    }

    function test_2_rofi_becomes_the_custom_command() {
        compare(MigrationSteps.toVersion2({ launcher: { searchProvider: "rofi", layout: "grid" } }),
                { launcher: { searchProvider: "custom", layout: "grid", command: ["rofi", "-show", "drun"] } });
    }

    function test_2_both_on_the_same_one() {
        compare(MigrationSteps.toVersion2({ launcher: { provider: "rofi", searchProvider: "rofi" } }),
                { launcher: { provider: "custom", searchProvider: "custom", command: ["rofi", "-show", "drun"] } });
    }

    // One custom command: the menu's choice keeps it, the search goes back
    // to automatic -- the built-in -- rather than running fuzzel as "rofi".
    function test_2_menu_and_search_on_different_ones() {
        compare(MigrationSteps.toVersion2({ launcher: { provider: "fuzzel", searchProvider: "rofi" } }),
                { launcher: { provider: "custom", searchProvider: "auto", command: ["fuzzel"] } });
    }

    // A command of somebody's own is never overwritten.
    function test_2_keeps_a_command_of_its_own() {
        compare(MigrationSteps.toVersion2({ launcher: { provider: "fuzzel", searchProvider: "custom", command: ["walker"] } }),
                { launcher: { provider: "auto", searchProvider: "custom", command: ["walker"] } });
        compare(MigrationSteps.toVersion2({ launcher: { provider: "fuzzel", command: ["fuzzel"] } }),
                { launcher: { provider: "custom", command: ["fuzzel"] } });
        compare(MigrationSteps.toVersion2({ launcher: { provider: "rofi", command: [] } }),
                { launcher: { provider: "custom", command: ["rofi", "-show", "drun"] } });
    }

    function test_2_leaves_everything_else_alone() {
        const profile = { theme: { mode: "dark" }, launcher: { provider: "kickoff", searchProvider: "custom", command: ["wofi"] } };
        compare(MigrationSteps.toVersion2(profile), profile);
        compare(MigrationSteps.toVersion2({}), {});
        compare(MigrationSteps.toVersion2(undefined), {});
        compare(MigrationSteps.toVersion2({ launcher: { provider: "toString" } }), { launcher: { provider: "toString" } });
    }

    // A pure function: what it was given is not what it changes.
    function test_2_does_not_touch_its_input() {
        const profile = { launcher: { provider: "fuzzel" } };
        MigrationSteps.toVersion2(profile);
        compare(profile, { launcher: { provider: "fuzzel" } });
    }
}
