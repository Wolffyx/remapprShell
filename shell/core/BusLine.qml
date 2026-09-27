pragma Singleton

// One line of `busctl --json=short monitor`, made safe to parse.
//
// Every bus listener in this shell reads lines from a `busctl` process and
// hands them to JSON.parse. That step is not safe by default, and the reason
// is a detail of how busctl renders DBus types: a byte array, `ay`, becomes
// one JSON integer per byte. An application with no icon file sends its icon
// as pixels in a notification hint, so a 512x512 icon arrives as a 3.7 MB line
// holding a million numbers -- and parsing it segfaults the QML engine from
// inside the read handler. No QML error, nothing in the journal, and a stack
// that is all Qt internals. It took the shell down five times before it was
// found.
//
// So the rule this file exists to enforce: **a line off a bus monitor is
// unbounded input, even on your own desktop.** It is bounded here, once, and
// every listener goes through it -- rather than each one being fixed after it
// is the one that crashes.
//
// Pure, and in core, so the three parsers that use it stay loadable by
// qmltestrunner (see scripts/lint-tests.sh).

import QtQuick

QtObject {
    id: root

    // A run of this many plain integers in a row is a byte array. Nothing any
    // parser here reads is a number in a long list: summaries, titles, icon
    // names and window ids are strings. Sixty-four is far above any honest
    // array on this bus and far below the smallest icon anyone sends.
    readonly property int byteRunLength: 64

    // A line still this large once byte arrays are out is not something to
    // hand to JSON.parse. It should not happen; if it does, dropping one
    // message is the right answer and the shell stays up.
    readonly property int maxLength: 1048576

    // Counted rather than logged: this runs inside a hot read handler, and a
    // pure function has nowhere to log to anyway. The services that care read
    // this and say so once.
    property int dropped: 0

    // Removes byte arrays from a line, leaving everything else as it was.
    //
    // A string pass rather than a structural one, because the structure is
    // exactly what cannot be built: this runs before JSON.parse, on the line
    // that would kill the engine.
    //
    // Quotes and escapes are respected. A notification body reading
    // "1, 2, 3, ..." is text, and text must not be edited on its way past --
    // the message a person sees and the one recorded have to be the same one.
    function stripByteArrays(line) {
        if (!line || line.indexOf("[") < 0)
            return line;

        let out = "";
        let i = 0;

        while (i < line.length) {
            const c = line[i];

            // A string is copied whole, so nothing inside one is ever read
            // as an array.
            if (c === '"') {
                const end = root._stringEnd(line, i);
                out += line.slice(i, end);
                i = end;
                continue;
            }

            const arrayEnd = c === "[" ? root._byteArrayEnd(line, i) : -1;
            if (arrayEnd >= 0) {
                out += "[]";
                i = arrayEnd;
                continue;
            }

            out += c;
            i++;
        }

        return out;
    }

    // The index just past the quote that closes the string opening at
    // `start`, or the end of the line when nothing closes it. An escape takes
    // the next character with it, so a backslash before a quote does not end
    // the string.
    function _stringEnd(line, start) {
        let j = start + 1;
        while (j < line.length) {
            if (line[j] === "\\")
                j += 2;
            else if (line[j] === '"')
                return j + 1;
            else
                j++;
        }
        return line.length;
    }

    // The index just past the `]` of a byte array opening at `start` -- a
    // run of at least byteRunLength integers -- or -1 when there is none.
    function _byteArrayEnd(line, start) {
        const run = root._integerRun(line, start + 1);
        return line[run.end] === "]" && run.count >= root.byteRunLength ? run.end + 1 : -1;
    }

    // The run of comma-separated integers starting at `start`, measured
    // without keeping any of it: how many there are, and the index of the
    // first character that is not part of the run.
    function _integerRun(line, start) {
        let j = start;
        let count = 0;
        let digits = 0;
        while (j < line.length) {
            const d = line[j];
            if (d >= "0" && d <= "9") {
                digits++;
            } else if (d === "," && digits > 0) {
                count++;
                digits = 0;
            } else {
                break;
            }
            j++;
        }
        return { end: j, count: digits > 0 ? count + 1 : count };
    }

    // The parsed message, or null for anything that is not one: a banner line,
    // a partial read, malformed JSON, or a line too large to be worth the
    // risk. Null rather than a half-filled object, always -- every caller
    // treats null as "not a message" and carries on.
    function parse(line) {
        if (!line || line.length === 0)
            return null;

        const text = root.stripByteArrays(line);
        if (text.length > root.maxLength) {
            root.dropped++;
            return null;
        }

        try {
            return JSON.parse(text);
        } catch (e) {
            return null;
        }
    }

    // True when the message is a signal on that interface. The check every
    // listener does, spelled once.
    function isSignal(msg, interfaceName, member) {
        return !!msg && msg.type === "signal"
            && msg.interface === interfaceName
            && (member === undefined || msg.member === member);
    }

    function isCall(msg, interfaceName, member) {
        return !!msg && msg.type === "method_call"
            && msg.interface === interfaceName
            && (member === undefined || msg.member === member);
    }

    // The `data` array of a message payload, or null when there is not one.
    function payload(msg, least) {
        const data = msg?.payload?.data;
        if (!Array.isArray(data) || data.length < (least ?? 0))
            return null;
        return data;
    }

    // An a{sv} as `busctl --json=short` renders it -- [{ Name: { type, data } }],
    // the reply to a Properties.GetAll -- as a plain { Name: value }. Anything
    // else is an empty object.
    function props(data) {
        const first = Array.isArray(data) ? data[0] : null;
        const out = {};
        if (!first || typeof first !== "object")
            return out;
        for (const key of Object.keys(first))
            out[key] = first[key]?.data;
        return out;
    }
}
