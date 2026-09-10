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

import QtQuick

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
        if (!line || line.length === 0)
            return null;

        let msg;
        try {
            msg = JSON.parse(line);
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
