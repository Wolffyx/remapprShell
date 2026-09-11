// Tests for how the notification centre arranges the history.

import QtQuick
import QtTest
import qs.domain.notifications.centre

TestCase {
    name: "Centre"

    readonly property real now: new Date(2026, 8, 11, 14, 30).getTime()

    function entry(app, minutesAgo, icon) {
        return { appName: app, appIcon: icon ?? "", summary: `${app} ${minutesAgo}`, body: "",
                 urgency: 1, when: now - minutesAgo * 60000 };
    }

    function test_grouped_by_application_most_recent_first() {
        const g = Centre.groups([entry("Messages", 2), entry("System", 18), entry("Messages", 40, "chat"),
                                 entry("Power", 60)]);
        compare(g.length, 3);
        compare(g[0].app, "Messages");
        compare(g[0].entries.length, 2);
        compare(g[0].entries[0].summary, "Messages 2");
        compare(g[1].app, "System");
        compare(g[2].app, "Power");
    }

    function test_a_group_takes_the_first_icon_it_is_given() {
        const g = Centre.groups([entry("Messages", 2), entry("Messages", 40, "chat")]);
        compare(g[0].icon, "chat");
    }

    function test_nameless_notifications_group_together() {
        const g = Centre.groups([entry("", 1), entry("  ", 2)]);
        compare(g.length, 1);
        compare(g[0].app, "Notifications");
    }

    function test_buckets() {
        const b = Centre.buckets([entry("A", 5), entry("B", 60 * 16), entry("C", 60 * 40)], now);
        compare(b.length, 3);
        compare(b[0].label, "Today");
        compare(b[0].entries.length, 1);
        compare(b[1].label, "Yesterday");
        compare(b[2].label, "Earlier");
    }

    function test_empty_buckets_are_left_out() {
        const b = Centre.buckets([entry("A", 5), entry("B", 10)], now);
        compare(b.length, 1);
        compare(b[0].label, "Today");
        compare(Centre.buckets([], now).length, 0);
    }

    function test_ago() {
        compare(Centre.ago(now - 20 * 1000, now), "now");
        compare(Centre.ago(now - 2 * 60000, now), "2m");
        compare(Centre.ago(now - 90 * 60000, now), "1h");
        compare(Centre.ago(now - 3 * 86400000, now), "3d");
        compare(Centre.ago(now + 5000, now), "now");
    }
}
