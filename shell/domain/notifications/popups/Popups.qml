pragma Singleton

// The rules for this shell's own notification popups, as pure functions.
//
// A leaf module with nothing from Quickshell in it, so qmltestrunner can load
// it: the timing of a popup is what people notice when it is wrong -- a
// critical one that vanishes, an ordinary one that never does -- so it is
// tested rather than trusted.

import QtQuick

QtObject {
    id: root

    readonly property int critical: 2

    // How long a popup stays, in ms, or 0 for until it is closed. The spec's
    // expire_timeout: 0 is never, a positive value is the application's own,
    // -1 is ours. A critical notification stays whatever it asks for, as
    // Plasma's do, and nothing flashes past faster than it can be read.
    function timeoutFor(urgency, expireTimeout, defaultMs) {
        if (Number(urgency) >= root.critical)
            return 0;
        const asked = Number(expireTimeout);
        if (asked === 0)
            return 0;
        if (Number.isFinite(asked) && asked > 0)
            return Math.max(asked, 1500);
        return Math.max(1500, Number(defaultMs) || 6000);
    }

    // Do-not-disturb holds back everything but critical notifications.
    function admits(dnd, urgency) {
        return !dnd || Number(urgency) >= root.critical;
    }

    // Which popups to draw, from [{ id, urgency }]: critical first, then the
    // newest (ids count up), at most `max`. A critical one is never pushed off
    // the screen by ordinary ones arriving after it.
    function arrange(items, max) {
        const list = (items ?? []).filter(x => x);
        list.sort((a, b) => ((Number(b.urgency) >= root.critical) - (Number(a.urgency) >= root.critical))
                            || (Number(b.id) - Number(a.id)));
        return list.slice(0, Math.max(0, max ?? 0));
    }

    // The ids whose time is up, from { id: deadline in ms } against `now`,
    // sparing the one under the pointer. A deadline of 0 is never.
    function due(deadlines, now, held) {
        const out = [];
        for (const key of Object.keys(deadlines ?? {})) {
            const at = Number(deadlines[key]);
            if (at > 0 && at <= now && String(key) !== String(held))
                out.push(Number(key));
        }
        return out;
    }

    // When the pointer leaves a popup it gets a moment more, rather than
    // vanishing the instant it is let go of.
    function released(deadline, now) {
        return Number(deadline) > 0 ? Math.max(Number(deadline), now + 2000) : 0;
    }

    // The history's index for a notification, so "Ask" can name it to `rmpr
    // ask --notification`. Looked up when asked rather than when the popup
    // appeared: the eavesdrop that fills the history and the server that
    // draws the popup see the same call, in either order. The history is
    // newest first, so the latest of two identical notifications is the one
    // found.
    function historyIndex(entries, n) {
        if (!n)
            return -1;
        return (entries ?? []).findIndex(e => e && e.appName === n.appName
                                          && e.summary === n.summary && e.body === n.body);
    }

    // Where popups appear: a corner, or the middle of the top or the bottom
    // edge. "auto" is the right-hand end of the panel's edge, beside the
    // clock, where Windows and Plasma put them; the top right when the panel
    // runs down a side.
    readonly property var corners: ["top-right", "top-left", "top-center", "bottom-right", "bottom-left", "bottom-center"]

    function corner(position, panelEdge) {
        if (root.corners.indexOf(position) >= 0)
            return position;
        return panelEdge === "bottom" ? "bottom-right" : "top-right";
    }

    // A body as plain text. Markup is not advertised, but not every
    // application asks before sending it, and the body is drawn as plain text
    // -- never as rich text a sender could fill with links or remote images.
    function plain(text) {
        return String(text ?? "")
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&#39;|&apos;/g, "'")
            .replace(/&amp;/g, "&")
            .trim();
    }

    // What to draw as the icon: the image the server made, else the
    // application's icon, by path or by name. Returns { kind: "image" |
    // "name", value }.
    //
    // An icon sent with `notify-send -i` arrives as image://icon/<name>,
    // measured, with the icon field itself empty. That is a name, and is
    // looked up as one: the image provider has no fallback, and a name the
    // theme lacks drew Qt's magenta checkerboard.
    function iconOf(image, appIcon) {
        const img = String(image ?? "");
        if (img.startsWith("image://icon/"))
            return { kind: "name", value: img.slice("image://icon/".length) || "dialog-information" };
        if (img)
            return { kind: "image", value: img };
        const icon = String(appIcon ?? "");
        if (icon.startsWith("file://"))
            return { kind: "image", value: icon };
        if (icon.startsWith("/"))
            return { kind: "image", value: `file://${icon}` };
        return { kind: "name", value: icon || "dialog-information" };
    }
}
