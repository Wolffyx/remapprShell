// Tests for the OSD signal parser.
//
// This is the part whose failure looks like "the OSD sometimes does not
// appear": a payload one element short, a member we do not handle, a line that
// is not a signal at all. All of them must produce nothing rather than a
// half-filled event.

import QtQuick
import QtTest
import qs.domain.osd.events

TestCase {
    name: "OsdEvents"

    function signalLine(member, data) {
        return JSON.stringify({
            type: "signal",
            sender: ":1.42",
            path: "/org/kde/osdService",
            interface: "org.kde.osdService",
            member: member,
            payload: { type: "siis", data: data }
        });
    }

    function test_progress() {
        const e = OsdEvents.parse(signalLine("osdProgress", ["audio-volume-high", 45, 100, ""]));
        verify(e !== null);
        compare(e.icon, "audio-volume-high");
        compare(e.value, 45);
        compare(e.maxValue, 100);
        compare(e.showingProgress, true);
    }

    function test_progress_carries_additional_text() {
        const e = OsdEvents.parse(signalLine("osdProgress", ["video-display", 60, 100, "HDMI-1"]));
        compare(e.text, "HDMI-1");
    }

    function test_text() {
        const e = OsdEvents.parse(signalLine("osdText", ["input-keyboard", "Caps Lock on"]));
        verify(e !== null);
        compare(e.text, "Caps Lock on");
        compare(e.showingProgress, false);
    }

    // Seen on the bus. Every bar that draws it would divide by zero.
    function test_zero_maximum_becomes_a_usable_one() {
        const e = OsdEvents.parse(signalLine("osdProgress", ["x", 5, 0, ""]));
        compare(e.maxValue, 100);
    }

    function test_short_payload_is_not_an_event() {
        compare(OsdEvents.parse(signalLine("osdProgress", ["x", 5])), null);
        compare(OsdEvents.parse(signalLine("osdText", ["x"])), null);
    }

    function test_other_members_are_ignored() {
        compare(OsdEvents.parse(signalLine("kbdLayoutChanged", ["us"])), null);
    }

    function test_other_interfaces_are_ignored() {
        const line = JSON.stringify({
            type: "signal",
            interface: "org.freedesktop.Notifications",
            member: "osdProgress",
            payload: { data: ["x", 1, 100, ""] }
        });
        compare(OsdEvents.parse(line), null);
    }

    function test_method_calls_are_ignored() {
        const line = JSON.stringify({
            type: "method_call",
            interface: "org.kde.osdService",
            member: "osdProgress",
            payload: { data: ["x", 1, 100, ""] }
        });
        compare(OsdEvents.parse(line), null);
    }

    // busctl prints a banner and can hand us a partial line on a short read.
    function test_junk_is_not_an_event() {
        compare(OsdEvents.parse(""), null);
        compare(OsdEvents.parse("Monitoring bus message stream."), null);
        compare(OsdEvents.parse('{"type":"signal","interf'), null);
    }
}
