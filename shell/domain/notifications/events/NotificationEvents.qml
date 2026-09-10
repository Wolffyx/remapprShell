pragma Singleton

// Turns one line of `busctl --json=short monitor` into a notification.
//
// The eavesdrop watches org.freedesktop.Notifications for `Notify` method
// calls -- the message every application sends to Plasma's notification
// daemon. We are a bystander on that bus: nothing is claimed, Plasma still
// draws every popup, and switching this off leaves it exactly as it was.
//
// Kept apart from the process that reads the bus for the same reason the OSD
// parser is: a Quickshell-dependent singleton makes its whole module
// unimportable by qmltestrunner, and this is the part that deserves a test. A
// hints table arriving as variants, a body that is missing, a call that is
// not `Notify` at all -- each of those must produce nothing rather than a
// half-filled entry with somebody's file path in it.
//
// And one that must produce nothing rather than a crash: an `image-data` hint.
// An application that has no icon file sends its icon as pixels, `(iiibiiay)`,
// and `busctl --json=short` renders that byte array as one JSON integer per
// byte. A 512x512 icon is a million numbers on a single line, and JSON.parse
// on it takes the QML engine down -- a segfault inside the read handler, with
// no QML error and nothing in the log, which is how this was first seen: three
// crash dumps and a shell that kept dying at no particular time. Telegram,
// Spotify and KDE Connect all send icons this way, so this is ordinary desktop
// traffic rather than a hostile case.
//
// The pixels are stripped before the line is parsed, never after: after is too
// late, since parsing is the step that dies. Nothing is lost by it -- the only
// icon this reads is `image-path`, which is a string.

import QtQuick

QtObject {
    id: root

    readonly property string interfaceName: "org.freedesktop.Notifications"

    // A run of this many plain integers in a row is pixel data. Nothing we
    // read is a number at all: the summary, body, icon and desktop entry are
    // strings and the actions are a list of strings, so no honest field can be
    // caught by this. Sixty-four is far above any array a notification carries
    // and far below the smallest icon anyone sends.
    readonly property int pixelRunLength: 64

    // A line still this large once the pixels are out is not something to hand
    // to JSON.parse. It should not happen; if it does, dropping one
    // notification is the right answer and the shell stays up.
    readonly property int maxLineLength: 1048576

    // Set when a line was dropped for being too large, so the service can say
    // so once rather than the parser logging from inside a hot handler.
    property int dropped: 0

    // Removes byte arrays from a busctl JSON line, leaving the rest intact.
    // A string pass rather than a structural one, because the structure is
    // exactly what cannot be built: this runs before JSON.parse, on the line
    // that would kill the engine.
    //
    // Quotes are respected. A body reading "1, 2, 3, ..." is text, and text
    // must not be edited on its way past -- the notification a person sees and
    // the one this records have to be the same one.
    function stripByteArrays(line) {
        if (!line || line.indexOf("[") < 0)
            return line;

        let out = "";
        let i = 0;
        let inString = false;

        while (i < line.length) {
            const c = line[i];

            if (inString) {
                out += c;
                if (c === "\\") {
                    // An escape takes the next character with it, so a
                    // backslash before a quote does not end the string.
                    if (i + 1 < line.length)
                        out += line[i + 1];
                    i += 2;
                    continue;
                }
                if (c === '"')
                    inString = false;
                i++;
                continue;
            }

            if (c === '"') {
                inString = true;
                out += c;
                i++;
                continue;
            }

            if (c === "[") {
                // Measure the run of integers this bracket opens, without
                // keeping any of it.
                let j = i + 1;
                let count = 0;
                let digits = 0;
                while (j < line.length) {
                    const d = line[j];
                    if (d >= "0" && d <= "9") {
                        digits++;
                        j++;
                    } else if (d === "," && digits > 0) {
                        count++;
                        digits = 0;
                        j++;
                    } else {
                        break;
                    }
                }
                if (digits > 0)
                    count++;

                if (line[j] === "]" && count >= root.pixelRunLength) {
                    out += "[]";
                    i = j + 1;
                    continue;
                }
            }

            out += c;
            i++;
        }

        return out;
    }

    // busctl renders an a{sv} as { key: { type, data } }. Anything else is
    // taken as already unwrapped, which is what a hand-written fixture is.
    function _hint(hints, name) {
        if (!hints || typeof hints !== "object")
            return undefined;
        const v = hints[name];
        if (v && typeof v === "object" && "data" in v)
            return v.data;
        return v;
    }

    // Returns { appName, appIcon, summary, body, actions, urgency, desktopEntry,
    // when } or null.
    function parse(line, now) {
        if (!line || line.length === 0)
            return null;

        // Before anything else, including the cheap checks below: the whole
        // point is that this line must never reach JSON.parse intact.
        const text = root.stripByteArrays(line);
        if (text.length > root.maxLineLength) {
            root.dropped++;
            return null;
        }

        let msg;
        try {
            msg = JSON.parse(text);
        } catch (e) {
            return null;   // banner lines and partial reads
        }

        if (msg.type !== "method_call" || msg.interface !== root.interfaceName
                || msg.member !== "Notify")
            return null;

        const data = msg.payload?.data;
        // The spec's argument list: app_name, replaces_id, app_icon, summary,
        // body, actions, hints, expire_timeout. A call short of the summary is
        // not a notification anyone could have seen.
        if (!Array.isArray(data) || data.length < 4)
            return null;

        const hints = data[6];
        const urgency = Number(root._hint(hints, "urgency"));

        // busctl stamps microseconds since the epoch; a fixture may carry
        // nothing, and the caller may pass a clock for the test's sake.
        const stamp = Number(msg["timestamp-realtime"]);
        const when = Number.isFinite(stamp) && stamp > 0
            ? Math.floor(stamp / 1000)
            : (now ?? Date.now());

        return {
            appName: String(data[0] ?? ""),
            appIcon: String(data[2] ?? "") || String(root._hint(hints, "image-path") ?? ""),
            summary: String(data[3] ?? ""),
            body: String(data[4] ?? ""),
            actions: Array.isArray(data[5]) ? data[5].map(a => String(a)) : [],
            // 0 low, 1 normal, 2 critical. Absent means normal, per the spec.
            urgency: Number.isFinite(urgency) ? urgency : 1,
            desktopEntry: String(root._hint(hints, "desktop-entry") ?? ""),
            when: when
        };
    }
}
