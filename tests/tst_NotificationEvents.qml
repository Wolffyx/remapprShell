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

    // ---- image-data: the case that took the shell down ----------------
    //
    // An application with no icon file sends its icon as pixels, and busctl
    // renders that byte array as one integer per byte. Parsing a 512x512 one
    // segfaults the QML engine from inside the read handler. Reproduced with
    // a real notification before this test was written.

    function pixels(n) {
        const a = [];
        for (let i = 0; i < n; i++)
            a.push(i % 256);
        return a;
    }

    function imageLine(n) {
        return JSON.stringify({
            type: "method_call",
            interface: "org.freedesktop.Notifications",
            member: "Notify",
            payload: {
                type: "susssasa{sv}i",
                data: ["image-probe", 0, "", "Image probe", "has an image-data hint", [],
                       {
                           "image-data": {
                               type: "(iiibiiay)",
                               data: [64, 64, 256, true, 8, 4, pixels(n)]
                           },
                           "urgency": { type: "y", data: 1 }
                       }, -1]
            }
        });
    }

    function test_a_notification_carrying_pixels_still_arrives() {
        const line = imageLine(16384);
        verify(line.length > 50000);
        const e = NotificationEvents.parse(line);
        verify(e !== null);
        compare(e.summary, "Image probe");
        compare(e.body, "has an image-data hint");
        compare(e.appName, "image-probe");
    }

    // The size that crashed a running shell. A quarter of a million pixels.
    function test_a_large_image_does_not_take_the_parser_with_it() {
        const e = NotificationEvents.parse(imageLine(1048576));
        verify(e !== null);
        compare(e.summary, "Image probe");
    }

    function test_the_pixels_are_gone_before_parsing() {
        const stripped = NotificationEvents.stripByteArrays(imageLine(16384));
        verify(stripped.length < 1000);
        verify(stripped.indexOf("image-data") >= 0);
        compare(JSON.parse(stripped).payload.data[6]["image-data"].data[6].length, 0);
    }

    // The dimensions in front of the byte array are a short list and must
    // survive; so must a notification's actions, which are strings.
    function test_short_arrays_are_left_alone() {
        const stripped = NotificationEvents.stripByteArrays(imageLine(16384));
        const img = JSON.parse(stripped).payload.data[6]["image-data"].data;
        compare(img[0], 64);
        compare(img[1], 64);
        compare(img[2], 256);
    }

    function test_actions_survive_the_strip() {
        const e = NotificationEvents.parse(call(["a", 0, "", "s", "b", ["default", "Open"], {}, -1]));
        compare(e.actions.length, 2);
        compare(e.actions[1], "Open");
    }

    // Text that looks like pixel data is text. The notification a person sees
    // and the one recorded here have to be the same one.
    function test_a_body_full_of_numbers_is_not_touched() {
        let body = "1";
        for (let i = 2; i <= 200; i++)
            body += "," + i;
        const e = NotificationEvents.parse(call(["a", 0, "", "counts", body, [], {}, -1]));
        compare(e.body, body);
    }

    function test_a_bracketed_list_inside_a_string_is_not_touched() {
        const body = "[" + Array.from({length: 200}, (_, i) => i).join(",") + "]";
        const e = NotificationEvents.parse(call(["a", 0, "", "s", body, [], {}, -1]));
        compare(e.body, body);
    }

    // A quote escaped inside a body must not end the string early, or
    // everything after it would be scanned as if it were structure.
    function test_an_escaped_quote_does_not_confuse_the_scanner() {
        const body = 'he said "[1,2,3]" and left';
        const e = NotificationEvents.parse(call(["a", 0, "", "s", body, [], {}, -1]));
        compare(e.body, body);
    }

    function test_a_line_too_big_even_stripped_is_dropped() {
        const before = NotificationEvents.dropped;
        let body = "";
        while (body.length < NotificationEvents.maxLineLength + 1000)
            body += "abcdefghij";
        compare(NotificationEvents.parse(call(["a", 0, "", "s", body, [], {}, -1])), null);
        compare(NotificationEvents.dropped, before + 1);
    }

    function test_junk_is_not_a_notification() {
        compare(NotificationEvents.parse(""), null);
        compare(NotificationEvents.parse("Monitoring bus message stream."), null);
        compare(NotificationEvents.parse('{"type":"method_call","interf'), null);
    }
}
