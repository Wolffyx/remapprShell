// Tests for the guard every bus listener parses through.
//
// This is the file that exists because the shell died five times. An
// application with no icon file sends its icon as pixels, busctl renders that
// byte array as one JSON integer per byte, and JSON.parse on the result
// segfaults the QML engine from inside a read handler -- no QML error, nothing
// in the journal. Reproduced with a real notification before any of this was
// written.
//
// Two things are being checked, and the second matters as much as the first:
// that a byte array never reaches the parser, and that nothing else is
// touched on its way past. A guard that quietly edits a window title or a
// notification body would be its own kind of bug.

import QtQuick
import QtTest
import qs.core

TestCase {
    name: "BusLine"

    function pixels(n) {
        const a = [];
        for (let i = 0; i < n; i++)
            a.push(i % 256);
        return a;
    }

    function lineWith(hints) {
        return JSON.stringify({
            type: "method_call",
            interface: "org.freedesktop.Notifications",
            member: "Notify",
            payload: { data: ["app", 0, "", "summary", "body", [], hints, -1] }
        });
    }

    // ---- the crash ----------------------------------------------------

    function test_a_byte_array_is_gone_before_parsing() {
        const line = lineWith({ "image-data": { type: "(iiibiiay)", data: [64, 64, 256, true, 8, 4, pixels(16384)] } });
        verify(line.length > 50000);

        const stripped = BusLine.stripByteArrays(line);
        verify(stripped.length < 1000);
        // The hint is still there, with nothing in it. Removing the whole
        // entry would change the shape of the message.
        verify(stripped.indexOf("image-data") >= 0);
        compare(JSON.parse(stripped).payload.data[6]["image-data"].data[6].length, 0);
    }

    // The size that took the shell down, and four times that.
    function test_a_large_line_still_parses() {
        for (const n of [262144, 1048576]) {
            const msg = BusLine.parse(lineWith({ "image-data": { type: "(iiibiiay)", data: [1, 1, 1, true, 8, 4, pixels(n)] } }));
            verify(msg !== null);
            compare(msg.payload.data[3], "summary");
        }
    }

    // The dimensions in front of the pixels are a short list and must survive.
    function test_short_arrays_are_left_alone() {
        const stripped = BusLine.stripByteArrays(lineWith({ "image-data": { type: "(iiibiiay)", data: [64, 48, 256, true, 8, 4, pixels(16384)] } }));
        const img = JSON.parse(stripped).payload.data[6]["image-data"].data;
        compare(img[0], 64);
        compare(img[1], 48);
        compare(img[2], 256);
    }

    function test_the_threshold_is_where_it_says_it_is() {
        const under = "[" + pixels(BusLine.byteRunLength - 1).join(",") + "]";
        const over = "[" + pixels(BusLine.byteRunLength).join(",") + "]";
        compare(BusLine.stripByteArrays(under), under);
        compare(BusLine.stripByteArrays(over), "[]");
    }

    // ---- what must not be touched --------------------------------------

    function test_a_string_full_of_numbers_is_text() {
        const body = Array.from({length: 300}, (_, i) => i).join(",");
        const line = JSON.stringify({ payload: { data: [body] } });
        compare(JSON.parse(BusLine.stripByteArrays(line)).payload.data[0], body);
    }

    function test_a_bracketed_list_inside_a_string_is_text() {
        const body = "[" + Array.from({length: 300}, (_, i) => i).join(",") + "]";
        const line = JSON.stringify({ payload: { data: [body] } });
        compare(JSON.parse(BusLine.stripByteArrays(line)).payload.data[0], body);
    }

    // A quote escaped inside a string must not end it early, or everything
    // after would be scanned as though it were structure.
    function test_an_escaped_quote_does_not_end_a_string() {
        const body = 'he said "' + Array.from({length: 200}, (_, i) => i).join(",") + '" and left';
        const line = JSON.stringify({ payload: { data: [body] } });
        compare(JSON.parse(BusLine.stripByteArrays(line)).payload.data[0], body);
    }

    function test_a_line_with_no_bracket_is_returned_as_it_is() {
        const line = '{"member":"Notify"}';
        compare(BusLine.stripByteArrays(line), line);
    }

    // ---- the cap --------------------------------------------------------

    function test_a_line_too_large_even_stripped_is_dropped() {
        const before = BusLine.dropped;
        let body = "";
        while (body.length < BusLine.maxLength + 1000)
            body += "abcdefghij";
        compare(BusLine.parse(JSON.stringify({ payload: { data: [body] } })), null);
        compare(BusLine.dropped, before + 1);
    }

    // ---- the things every listener asks ----------------------------------

    function test_junk_is_not_a_message() {
        compare(BusLine.parse(""), null);
        compare(BusLine.parse("Monitoring bus message stream."), null);
        compare(BusLine.parse('{"type":"signal","interf'), null);
    }

    function test_signals_and_calls_are_told_apart() {
        const signal = BusLine.parse(JSON.stringify({ type: "signal", interface: "org.kde.osdService", member: "osdText" }));
        verify(BusLine.isSignal(signal, "org.kde.osdService"));
        verify(BusLine.isSignal(signal, "org.kde.osdService", "osdText"));
        verify(!BusLine.isSignal(signal, "org.kde.osdService", "osdProgress"));
        verify(!BusLine.isSignal(signal, "org.freedesktop.Notifications"));
        verify(!BusLine.isCall(signal, "org.kde.osdService"));
    }

    function test_a_payload_shorter_than_asked_for_is_not_one() {
        const msg = BusLine.parse(JSON.stringify({ payload: { data: ["one", "two"] } }));
        compare(BusLine.payload(msg, 2).length, 2);
        compare(BusLine.payload(msg, 3), null);
        compare(BusLine.payload(BusLine.parse('{"member":"x"}'), 1), null);
    }

    // ---- replies ----------------------------------------------------------

    // The shape powerdevil replies to Properties.GetAll with for an external
    // monitor over DDC, the model name replaced by a stand-in.
    readonly property string getAll: '{"type":"a{sv}","data":[{"Brightness":{"type":"i","data":7500},'
        + '"IsInternal":{"type":"b","data":false},"Label":{"type":"s","data":"EXA Displays 27Q"},'
        + '"MaxBrightness":{"type":"i","data":10000}}]}'

    function test_properties_are_flattened() {
        const p = BusLine.props(JSON.parse(getAll).data);
        compare(p, { Brightness: 7500, IsInternal: false, Label: "EXA Displays 27Q", MaxBrightness: 10000 });
    }

    // A false and a zero are values, not absences.
    function test_falsy_properties_are_kept() {
        const p = BusLine.props([{ on: { type: "b", data: false }, n: { type: "u", data: 0 } }]);
        verify("on" in p && p.on === false);
        verify("n" in p && p.n === 0);
    }

    function test_anything_else_is_no_properties() {
        compare(BusLine.props(null), {});
        compare(BusLine.props(undefined), {});
        compare(BusLine.props([]), {});
        compare(BusLine.props(["a string"]), {});
        compare(BusLine.props({ Brightness: 1 }), {});
    }
}
