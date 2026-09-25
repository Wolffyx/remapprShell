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
            // Asked for the whole screen. False from a script older than the
            // field, which only means no panel steps aside for it.
            fullScreen: entry.fullScreen === true,
            // KWin's "this window wants you": an X11 urgency hint, or a
            // Wayland client asking to be activated while it is not. KWin
            // clears it when the window is activated.
            attention: entry.demandsAttention === true,
            // The monitor, as Quickshell names screens. Empty from a script
            // older than this field.
            output: String(entry.output ?? ""),
            // KWin's stacking position, higher on top; -1 when not sent.
            stacking: typeof entry.stacking === "number" ? entry.stacking : -1,
            // A PNG the daemon lifted out of the window itself -- the icon it
            // carries, drawn when its application has none to offer (see
            // AppMatch.icon). Empty for a window with no X11 icon to copy.
            iconPath: String(entry.iconPath ?? ""),
            // What AppMatch finds the window's application by, beyond its app
            // id: the instance half of an X11 class (a Wayland window's
            // executable), and what the daemon read about the process and
            // the desktop files named by it. All empty from a script or a
            // daemon older than the fields, which only means fewer steps
            // can match.
            resourceName: String(entry.resourceName ?? ""),
            pid: typeof entry.pid === "number" ? entry.pid : 0,
            cmdline: String(entry.cmdline ?? ""),
            processName: String(entry.processName ?? ""),
            executables: Array.isArray(entry.executables) ? entry.executables.map(w => String(w)) : [],
            desktopHint: root._desktopFile(entry.desktopHint),
            appIdFile: root._desktopFile(entry.appIdFile),
            // The virtual desktops it is on, as KWin's uuids. An empty list is
            // KWin's "on all of them", and so is a script too old to send the
            // field -- which is why anything filtering on this must treat
            // empty as "show it", never as "show it nowhere".
            //
            // Dropped here until 2026-09-14, which made every window look like
            // it was on every desktop: the overview listed all eleven under
            // each of two desktops.
            desktops: Array.isArray(entry.desktops) ? entry.desktops.map(d => String(d)) : [],
            // The window's shape on screen, for a preview to letterbox its
            // stream with. 0 from a script older than the field, which is why
            // anything using it needs a sensible aspect of its own.
            width: typeof entry.width === "number" ? entry.width : 0,
            height: typeof entry.height === "number" ? entry.height : 0,
            // Where it is, in the global coordinates Quickshell gives a
            // screen. 0 from a script older than the fields -- and with them
            // no size either, so nothing reads such a window as reaching an
            // edge.
            x: typeof entry.x === "number" ? entry.x : 0,
            y: typeof entry.y === "number" ? entry.y : 0
        };
    }

    // A desktop file the daemon read, as {variable, path, id, name, icon,
    // iconFile}, or null. Without a path it names nothing.
    function _desktopFile(value) {
        if (!value || typeof value !== "object" || String(value.path ?? "").length === 0)
            return null;
        return {
            variable: String(value.variable ?? ""),
            path: String(value.path),
            id: String(value.id ?? ""),
            name: String(value.name ?? ""),
            icon: String(value.icon ?? ""),
            iconFile: String(value.iconFile ?? "")
        };
    }

    // A window's shape, for letterboxing a picture of it. 16:9 when the window
    // did not say, which is the shape of the screen it is on more often than
    // not and a better guess than a square.
    function aspectOf(window) {
        const w = window?.width ?? 0;
        const h = window?.height ?? 0;
        return w > 0 && h > 0 ? w / h : 16 / 9;
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

    // Whether the window on top of `output`, on the desktop `desktopId`, is
    // full screen. Only windows that are actually showing count: a minimised
    // one, or one on another virtual desktop, covers nothing. A window on no
    // desktop in particular is on all of them. Ties in stacking -- a script too
    // old to send it -- go to whichever came first, as in the list.
    function fullScreenOn(windows, output, desktopId) {
        let top = null;
        for (const w of windows ?? []) {
            if (!w || w.minimized || w.output !== output)
                continue;
            const on = w.desktops ?? [];
            if (on.length > 0 && desktopId && on.indexOf(desktopId) < 0)
                continue;
            if (!top || (w.stacking ?? -1) > (top.stacking ?? -1))
                top = w;
        }
        return top !== null && top.fullScreen === true;
    }

    // Whether a window on the desktop `desktopId` reaches into the strip
    // `depth` pixels deep along `edge` of `screen` ({x, y, width, height}).
    // A floating panel fills its edge while one does, as Plasma's does.
    //
    // The strip is a pixel deeper than asked: a maximised window stops where
    // the panel's reserved space begins, which is touching it, not inside it.
    // By geometry rather than by `output`, so a window hanging over from the
    // next monitor counts on the monitor it reaches into.
    function reachesEdge(windows, desktopId, screen, edge, depth) {
        if (!screen || !(depth > 0))
            return false;
        const d = depth + 1;
        const sx = screen.x, sy = screen.y, sw = screen.width, sh = screen.height;
        const strip = edge === "top" ? { x: sx, y: sy, w: sw, h: d }
                    : edge === "left" ? { x: sx, y: sy, w: d, h: sh }
                    : edge === "right" ? { x: sx + sw - d, y: sy, w: d, h: sh }
                    : { x: sx, y: sy + sh - d, w: sw, h: d };
        for (const w of windows ?? []) {
            if (!w || w.minimized || !(w.width > 0) || !(w.height > 0))
                continue;
            const on = w.desktops ?? [];
            if (on.length > 0 && desktopId && on.indexOf(desktopId) < 0)
                continue;
            if (w.x < strip.x + strip.w && w.x + w.width > strip.x
                && w.y < strip.y + strip.h && w.y + w.height > strip.y)
                return true;
        }
        return false;
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

    // The icon name to try when neither the window's application nor the
    // window itself has an icon to draw (see AppMatch.icon).
    //
    // A desktop file id is the reliable one; the resource class is the
    // fallback, and lower-casing it is what turns "Example-Viewer" into an
    // icon that exists. The same rule for every window, whoever started it: a class
    // that names no icon in the theme gets the theme's generic application
    // icon where it is drawn, not another program's.
    function iconName(window) {
        if (!window)
            return "";
        if (window.desktopFile.length > 0)
            return window.desktopFile;
        return window.appId.toLowerCase();
    }

    // A hue per application, 0 to 1, for Qt.hsla: two windows of one program
    // are tinted alike and two programs apart. The window switcher and the
    // overview both tint their cards this way, so the same program looks the
    // same in both. A hash of the id, not a table -- any application gets
    // one, and always the same one.
    function tintHue(appId) {
        const s = String(appId ?? "");
        let h = 0;
        for (let i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 360;
        return h / 360;
    }
}
