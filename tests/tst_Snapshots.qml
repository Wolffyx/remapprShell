// Tests for how a restore point reads in a list.

import QtQuick
import QtTest
import qs.domain.settings.snapshots

TestCase {
    name: "Snapshots"

    function test_the_label_is_the_title() {
        compare(Snapshots.title("20260910-122741-before-renderer-quickshell"), "Before renderer quickshell");
        compare(Snapshots.title("20260915-101010-My shell setup"), "My shell setup");
    }

    function test_no_label_is_still_a_restore_point() {
        compare(Snapshots.title("20260910-122741"), "Restore point");
        compare(Snapshots.title(""), "Restore point");
        compare(Snapshots.title(undefined), "Restore point");
    }

    function test_a_stray_flag_is_not_left_dashing() {
        compare(Snapshots.title("20260915-101010---label"), "Label");
    }

    function test_when_says_it_as_a_person_would() {
        const now = new Date(2026, 8, 22, 16, 0, 0);
        compare(Snapshots.when("", "20260922-090500-x", now), "Today, 09:05");
        compare(Snapshots.when("", "20260921-235900-x", now), "Yesterday, 23:59");
        verify(Snapshots.when("", "20260909-200533-x", now).startsWith("9 "));
        verify(Snapshots.when("", "20260909-200533-x", now).endsWith(", 20:05"));
        verify(Snapshots.when("", "20250101-080000-x", now).indexOf("2025") >= 0);
    }

    function test_created_wins_over_the_name() {
        const now = new Date(2026, 8, 22, 16, 0, 0);
        const iso = new Date(2026, 8, 22, 7, 30, 0).toISOString();
        compare(Snapshots.when(iso, "20200101-000000-x", now), "Today, 07:30");
    }

    function test_nothing_to_read_says_nothing() {
        compare(Snapshots.when("", "manual", new Date()), "");
    }
}
