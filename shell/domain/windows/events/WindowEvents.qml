pragma Singleton

// Turns what the window daemon sends into a list the panel can draw.
//
// In a module of its own, with no Quickshell import anywhere in it, so it can
// be tested without a running shell -- the same reason qs.domain.osd.events
// exists. This is the part whose failure looks like "the taskbar is sometimes
// empty": a payload that crossed two process boundaries and a JSON string
// nested inside a DBus string.
//
// Nothing here trusts the payload. It arrives from a KWin script, through a
// daemon, over the bus; a malformed one must leave the previous list alone
// rather than blanking the panel.

import QtQuick
import qs.core

QtObject {
    id: root

    // A window we would put on a panel. The daemon has already dropped the
    // ones KWin marks skipTaskbar, so anything arriving here is meant to be
    // shown -- but the fields are still checked, because "meant to be" is not
    // the same as "is".
    function _window(entry) {
        if (!entry || typeof entry !== "object")
            return null;
        const uuid = String(entry.uuid ?? "");
        if (uuid.length === 0)
            return null;   // without one there is nothing to activate

        return {
            uuid: uuid,
            title: String(entry.title ?? ""),
            appId: String(entry.appId ?? ""),
            desktopFile: String(entry.desktopFile ?? ""),
            minimized: entry.minimized === true,
            active: entry.active === true,
            // A PNG the daemon lifted out of the window itself, for windows
            // that match no installed application. Empty for the rest.
            iconPath: String(entry.iconPath ?? "")
        };
    }

    // The daemon's JSON array. Returns null -- not an empty list -- when it
    // cannot be read, so a caller can tell "no windows" from "no answer" and
    // keep what it had.
    function parseList(json) {
        if (!json || json.length === 0)
            return null;

        let raw;
        try {
            raw = JSON.parse(json);
        } catch (e) {
            return null;
        }

        if (!Array.isArray(raw))
            return null;

        const out = [];
        for (const entry of raw) {
            const window = root._window(entry);
            if (window)
                out.push(window);
        }
        return out;
    }

    // One line of `busctl --json=short monitor`, which wraps the daemon's JSON
    // string inside a DBus payload.
    function parseSignal(line) {
        // Bounded before it is parsed. The daemon is ours and its payload is a
        // JSON string of a known shape, but the window titles inside it come
        // from whatever the user happens to be running, and that is not ours.
        const msg = BusLine.parse(line);
        if (!msg || msg.type !== "signal" || msg.member !== "Changed")
            return null;

        const data = BusLine.payload(msg, 1);
        if (!data)
            return null;

        return root.parseList(String(data[0]));
    }

    // What to show for a window: its title, or its application when the title
    // is empty -- some windows have none until they finish starting.
    function label(window) {
        if (!window)
            return "";
        return window.title.length > 0 ? window.title : window.appId;
    }

    // The icon name to try when no installed application matched the window.
    //
    // A desktop file id is the reliable one; the resource class is the
    // fallback, and lower-casing it is what turns "Google-chrome" into an icon
    // that exists.
    function iconName(window) {
        if (!window)
            return "";

        // A game launched through Steam has no desktop entry of its own -- its
        // class is the numeric app id -- so nothing above can have matched and
        // the only honest answer is Steam's icon rather than a blank square.
        if (/^steam_app_\d+$/.test(window.appId))
            return "steam";

        if (window.desktopFile.length > 0)
            return window.desktopFile;
        return window.appId.toLowerCase();
    }
}
