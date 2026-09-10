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
import qs.core

QtObject {
    id: root

    readonly property string interfaceName: "org.freedesktop.Notifications"

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
        // BusLine takes the pixels out and bounds the size before anything
        // here sees the line. That is the step this parser used to die in.
        const msg = BusLine.parse(line);
        if (!BusLine.isCall(msg, root.interfaceName, "Notify"))
            return null;

        // The spec's argument list: app_name, replaces_id, app_icon, summary,
        // body, actions, hints, expire_timeout. A call short of the summary is
        // not a notification anyone could have seen.
        const data = BusLine.payload(msg, 4);
        if (!data)
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
