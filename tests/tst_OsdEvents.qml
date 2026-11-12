// Tests for the OSD signal parser.
//
// This is the part whose failure looks like "the OSD sometimes does not
// appear": a payload one element short, a member we do not handle, a line that
// is not a signal at all. All of them must produce nothing rather than a
// half-filled event.

import QtQuick
import QtTest
import qs.domain.osd.events
import "fixtures/bus.js" as Bus

TestCase {
    name: "OsdEvents"

    function signalLine(member, data) {
        return Bus.signal("org.kde.osdService", member, "siis", data,
                          { sender: ":1.42", path: "/org/kde/osdService" });
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

    // ---- the events the shell raises itself ------------------------------

    function test_progress_is_a_bar() {
        const e = OsdEvents.progress("audio-volume-high", 42.4, "");
        compare(e.icon, "audio-volume-high");
        compare(e.value, 42);
        compare(e.maxValue, 100);
        compare(e.showingProgress, true);
        compare(e.text, "");
    }

    // PipeWire will amplify past 1.0, and a bar wider than its track is a
    // drawing bug rather than information.
    function test_progress_is_bounded() {
        compare(OsdEvents.progress("x", 150, "").value, 100);
        compare(OsdEvents.progress("x", -20, "").value, 0);
    }

    // A raised volume has a longer bar, and is bounded by that instead.
    function test_progress_has_a_longer_bar_when_asked() {
        const e = OsdEvents.progress("audio-volume-high", 120, "", 150);
        compare(e.value, 120);
        compare(e.maxValue, 150);
        compare(OsdEvents.progress("x", 180, "", 150).value, 150);
        compare(OsdEvents.progress("x", 50, "", 0).maxValue, 100);
        compare(OsdEvents.progress("x", 50, "", undefined).maxValue, 100);
    }

    // Plasma's volume bar is redrawn on this shell's scale; anything else is
    // left as it came.
    function test_on_scale() {
        const plasma = { icon: "audio-volume-high", text: "", value: 100, maxValue: 100, showingProgress: true };
        compare(OsdEvents.onScale(plasma, 150).maxValue, 150);
        compare(OsdEvents.onScale(plasma, 150).value, 100);
        const raised = { icon: "audio-volume-high", text: "", value: 120, maxValue: 150, showingProgress: true };
        compare(OsdEvents.onScale(raised, 120).maxValue, 120);
        const bright = { icon: "display-brightness", text: "", value: 40, maxValue: 100, showingProgress: true };
        compare(OsdEvents.onScale(bright, 150), bright);
        const muted = { icon: "audio-volume-muted", text: "Muted", value: 0, maxValue: 100, showingProgress: false };
        compare(OsdEvents.onScale(muted, 150), muted);
        compare(OsdEvents.onScale(plasma, 0), plasma);
        compare(OsdEvents.onScale(null, 150), null);
    }

    function test_progress_rejects_a_value_that_is_not_one() {
        compare(OsdEvents.progress("x", NaN, ""), null);
        compare(OsdEvents.progress("x", undefined, ""), null);
    }

    function test_message_has_no_bar() {
        const e = OsdEvents.message("microphone-sensitivity-muted", "Microphone muted");
        compare(e.text, "Microphone muted");
        compare(e.showingProgress, false);
        compare(e.value, 0);
    }

    // An OSD with nothing in it is not worth a second and a half of screen.
    function test_message_needs_words() {
        compare(OsdEvents.message("x", ""), null);
        compare(OsdEvents.message("x", null), null);
    }
}
