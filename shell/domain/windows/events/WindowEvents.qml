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
            // KWin's "this window wants you": an X11 urgency hint, or a
            // Wayland client asking to be activated while it is not. KWin
            // clears it when the window is activated.
            attention: entry.demandsAttention === true,
            // The monitor, as Quickshell names screens. Empty from a script
            // older than this field.
            output: String(entry.output ?? ""),
            // KWin's stacking position, higher on top; -1 when not sent.
            stacking: typeof entry.stacking === "number" ? entry.stacking : -1,
            // A PNG the daemon lifted out of the window itself, for windows
            // that match no installed application. Empty for the rest.
            iconPath: String(entry.iconPath ?? ""),
            // The virtual desktops it is on, as KWin's uuids. An empty list is
            // KWin's "on all of them", and so is a script too old to send the
            // field -- which is why anything filtering on this must treat
            // empty as "show it", never as "show it nowhere".
            //
            // Dropped here until 2026-09-14, which made every window look like
            // it was on every desktop: the overview listed all eleven under
            // each of two desktops.
            desktops: Array.isArray(entry.desktops) ? entry.desktops.map(d => String(d)) : []
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

    // When each window began asking for attention, keyed by uuid: the moment
    // from `previous` for a window still asking, `now` for one that has just
    // started, and nothing for one that has stopped or is the active window.
    // The task list flashes a button for a few seconds from that moment and
    // then holds a steady tint; keeping the moment here rather than in the
    // button is what stops every unrelated change to the list -- which
    // rebuilds the buttons -- from starting the flash again.
    function attentionSince(previous, windows, now) {
        const out = ({});
        for (const w of windows ?? []) {
            if (!w || !w.attention || w.active)
                continue;
            const since = previous ? previous[w.uuid] : 0;
            out[w.uuid] = since > 0 ? since : now;
        }
        return out;
    }

    // Which window was last active on each monitor: output name -> uuid. The
    // active window claims its monitor; every other monitor keeps the window
    // it had, for as long as that window still exists, is still on it and is
    // not minimised. KWin has one active window for the whole desktop, and a
    // panel per monitor naming it would say the same thing twice and nothing
    // about the other screen.
    function lastActiveByOutput(previous, windows) {
        const out = ({});
        const byUuid = ({});
        for (const w of windows ?? []) {
            if (w && w.uuid)
                byUuid[w.uuid] = w;
        }
        for (const output of Object.keys(previous ?? {})) {
            const w = byUuid[previous[output]];
            if (w && w.output === output && !w.minimized)
                out[output] = w.uuid;
        }
        for (const w of windows ?? []) {
            if (w && w.active && w.output)
                out[w.output] = w.uuid;
        }
        // A monitor nothing has been activated on since the shell started --
        // or whose window just went -- names the window on top there, rather
        // than nothing at all.
        const top = ({});
        for (const w of windows ?? []) {
            if (!w || !w.output || w.minimized || out[w.output])
                continue;
            if (!top[w.output] || (w.stacking ?? -1) > (top[w.output].stacking ?? -1))
                top[w.output] = w;
        }
        for (const output of Object.keys(top))
            out[output] = top[output].uuid;
        return out;
    }

    // The application a task item stands for, as a desktop entry id ("org.kde.
    // dolphin"). Empty for windows no installed application matched, which
    // are grouped by class and cannot be pinned or started again.
    function appIdOf(item) {
        if (!item)
            return "";
        if (item.appKey !== undefined)
            return String(item.appKey);
        const key = String(item.key ?? "");
        return key.startsWith("class:") ? "" : key;
    }

    // The task list in the order Windows keeps it: pinned applications first,
    // in the order they were pinned, each holding its windows when it has any
    // and otherwise a button that starts it -- `launcher(id)`, which answers
    // null for an application no longer installed, and that pin is skipped.
    // Then every other running item, in the order it appeared. Every item
    // comes back with `pinned`, and a launcher with `launcher: true`.
    function arrangeTasks(items, pinned, launcher) {
        const list = items ?? [];
        const out = [];
        const used = new Set();
        const seen = new Set();
        for (const raw of pinned ?? []) {
            const id = String(raw ?? "");
            if (!id || seen.has(id))
                continue;
            seen.add(id);
            const mine = list.filter(i => root.appIdOf(i) === id);
            if (mine.length > 0) {
                for (const i of mine) {
                    used.add(i);
                    out.push(Object.assign({}, i, { pinned: true, launcher: false }));
                }
            } else {
                const made = launcher ? launcher(id) : null;
                if (made)
                    out.push(Object.assign({}, made, { pinned: true, launcher: true }));
            }
        }
        for (const i of list) {
            if (!used.has(i))
                out.push(Object.assign({}, i, { pinned: false, launcher: false }));
        }
        return out;
    }

    // The pinned list with `id` added at the end, or taken out.
    function togglePinned(list, id) {
        const current = (list ?? []).map(String);
        const key = String(id ?? "");
        if (!key)
            return current;
        return current.indexOf(key) >= 0 ? current.filter(x => x !== key) : current.concat([key]);
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
