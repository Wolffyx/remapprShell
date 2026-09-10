// Tests for the notification eavesdrop parser.
//
// The fixture below is a real line, captured from `busctl --json=short monitor`
// on this machine after `notify-send`. What matters most here is the shape
// busctl gives the hints table -- variants wrapped as { type, data } -- and
// that anything short of a notification produces nothing.

import QtQuick
import QtTest
import qs.domain.notifications.events

TestCase {
    name: "NotificationEvents"

    readonly property string captured: '{"type":"method_call","endian":"l","flags":0,"version":1,"cookie":9,"timestamp-realtime":1789051619890040,"sender":":1.1825","destination":":1.45","path":"/org/freedesktop/Notifications","interface":"org.freedesktop.Notifications","member":"Notify","payload":{"type":"susssasa{sv}i","data":["probe-app",0,"","Probe summary","Probe body with /home/someone/x",[],{"image-path":{"type":"s","data":"dialog-information"},"urgency":{"type":"y","data":0},"sender-pid":{"type":"x","data":568015}},-1]}}'

    function call(data, extra) {
        return JSON.stringify(Object.assign({
            type: "method_call",
            interface: "org.freedesktop.Notifications",
            member: "Notify",
            payload: { type: "susssasa{sv}i", data: data }
        }, extra ?? {}));
    }

    function test_captured_line() {
        const e = NotificationEvents.parse(captured);
        verify(e !== null);
        compare(e.appName, "probe-app");
        compare(e.summary, "Probe summary");
        compare(e.body, "Probe body with /home/someone/x");
        compare(e.urgency, 0);
        compare(e.actions, []);
    }

    function test_icon_falls_back_to_the_image_path_hint() {
        const e = NotificationEvents.parse(captured);
        compare(e.appIcon, "dialog-information");
    }

    function test_app_icon_argument_wins_over_the_hint() {
        const e = NotificationEvents.parse(call(["a", 0, "explicit-icon", "s", "b", [], {"image-path": {type: "s", data: "hint-icon"}}, -1]));
        compare(e.appIcon, "explicit-icon");
    }

    function test_timestamp_is_taken_from_busctl_in_milliseconds() {
        const e = NotificationEvents.parse(captured);
        compare(e.when, 1789051619890);
    }

    function test_missing_timestamp_uses_the_clock_given() {
        const e = NotificationEvents.parse(call(["a", 0, "", "s", "b", [], {}, -1]), 12345);
        compare(e.when, 12345);
    }

    function test_urgency_defaults_to_normal() {
        const e = NotificationEvents.parse(call(["a", 0, "", "s", "b", [], {}, -1]));
        compare(e.urgency, 1);
    }

    function test_unwrapped_hints_are_accepted() {
        const e = NotificationEvents.parse(call(["a", 0, "", "s", "b", [], {urgency: 2, "desktop-entry": "org.kde.dolphin"}, -1]));
        compare(e.urgency, 2);
        compare(e.desktopEntry, "org.kde.dolphin");
    }

    function test_actions_are_kept_as_strings() {
        const e = NotificationEvents.parse(call(["a", 0, "", "s", "b", ["default", "Open", "dismiss", "Dismiss"], {}, -1]));
        compare(e.actions.length, 4);
        compare(e.actions[1], "Open");
    }

    function test_short_payload_is_not_a_notification() {
        compare(NotificationEvents.parse(call(["a", 0, ""])), null);
    }

    function test_other_members_are_ignored() {
        compare(NotificationEvents.parse(call(["a", 0, "", "s", "b", [], {}, -1], {member: "CloseNotification"})), null);
        compare(NotificationEvents.parse(call(["a", 0, "", "s", "b", [], {}, -1], {member: "GetCapabilities"})), null);
    }

    function test_signals_and_replies_are_ignored() {
        compare(NotificationEvents.parse(call(["a", 0, "", "s", "b", [], {}, -1], {type: "signal"})), null);
        compare(NotificationEvents.parse(call(["a", 0, "", "s", "b", [], {}, -1], {type: "method_return"})), null);
    }

    function test_other_interfaces_are_ignored() {
        compare(NotificationEvents.parse(call(["a", 0, "", "s", "b", [], {}, -1], {interface: "org.kde.osdService"})), null);
    }

    function test_junk_is_not_a_notification() {
        compare(NotificationEvents.parse(""), null);
        compare(NotificationEvents.parse("Monitoring bus message stream."), null);
        compare(NotificationEvents.parse('{"type":"method_call","interf'), null);
    }
}
