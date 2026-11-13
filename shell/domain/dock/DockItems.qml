pragma Singleton

// What the dock shows, in its order: the start button, the applications --
// pinned first, then the rest that are running -- and, past a divider, the
// places (Downloads and the Trash). Pure, and a leaf module, so it is tested
// (tst_DockItems); the windows and the installed applications come in from
// WindowsService through WindowEvents.arrangeTasks, which the taskbar uses
// too, so the two agree about what an application is.
//
// Every item is { kind, key, appName, iconName, ... }:
//   launcher   the start menu
//   app        an application: `appKey`, `windows`, `active`, `attention`,
//              `iconFile` -- an arranged task, as the taskbar has it
//   divider    the line before the places
//   place      a folder or the Trash: `uri`, opened with xdg-open

import QtQuick

QtObject {
    id: root

    // `apps` is arranged already (pinned first). `opts`:
    //   launcher  bool  the start button first
    //   running   bool  applications that are running and not pinned
    //   pinned    [id]  what is pinned, to tell the two apart
    //   places    bool  Downloads and the Trash at the end
    //   downloads text  the Downloads folder, a path
    function items(apps, opts) {
        const o = opts ?? {};
        const pins = new Set((o.pinned ?? []).map(id => String(id)));
        const shown = (apps ?? [])
            .filter(a => !!a && (o.running !== false || pins.has(String(a.appKey ?? ""))))
            .map(a => Object.assign({}, a, { kind: "app" }));
        const start = o.launcher === false ? []
            : [{ kind: "launcher", key: "launcher", appName: "Applications", iconName: "start-here-kde" }];
        return start.concat(shown, o.places === true ? root.places(o.downloads) : []);
    }

    // The divider and the two places.
    function places(downloads) {
        const dl = String(downloads ?? "");
        const folder = dl.length > 0
            ? [{ kind: "place", key: "downloads", appName: "Downloads", iconName: "folder-download",
                 uri: dl.startsWith("/") ? `file://${dl}` : dl }]
            : [];
        return [{ kind: "divider", key: "divider" }].concat(folder,
            [{ kind: "place", key: "trash", appName: "Trash", iconName: "user-trash", uri: "trash:/" }]);
    }

    // `pinned` with `id` added at the end, or taken out if it was there.
    function togglePin(pinned, id) {
        const key = String(id ?? "");
        const list = (pinned ?? []).map(p => String(p)).filter(p => p.length > 0);
        if (key.length === 0)
            return list;
        return list.indexOf(key) >= 0 ? list.filter(p => p !== key) : list.concat([key]);
    }

    // `pinned` with `id` taken out, or null when it was not kept: a tile
    // dragged off the dock (`dock.dragToRemove`).
    function unpin(pinned, id) {
        const key = String(id ?? "");
        const list = (pinned ?? []).map(p => String(p)).filter(p => p.length > 0);
        if (key.length === 0 || list.indexOf(key) < 0)
            return null;
        return list.filter(p => p !== key);
    }

    // How far a drag's `translation` ({x, y}) has carried a tile away from
    // the screen's edge, for a dock on `position`; negative towards it.
    readonly property var _awayFrom: ({
        bottom: t => -t.y,
        left: t => t.x,
        right: t => -t.x
    })

    function awayFromEdge(position, translation) {
        const away = root._awayFrom[position] ?? root._awayFrom.bottom;
        return Number(away(translation ?? {})) || 0;
    }

    // Whether a tile carried `away` pixels off a dock of `size` tiles is far
    // enough out to be taken out on release: past its own size and a quarter
    // again, so a drag along the dock that wanders never takes one out.
    readonly property real pullOff: 1.25

    function pulledOff(away, size) {
        const s = Number(size) || 0;
        if (s <= 0)
            return false;
        return (Number(away) || 0) >= root.pullOff * s;
    }

    // The tiles that can be dragged: applications that have a desktop entry
    // to keep. The start button, the divider and the places stay put, and so
    // does a window with no application behind it -- there is nothing to
    // write down for it.
    function draggable(item) {
        return item?.kind === "app" && String(item?.appKey ?? "").length > 0;
    }

    // The first and last index in `items` a dragged tile may land on: the
    // run of applications. [-1, -1] with none.
    function dropRange(items) {
        const list = items ?? [];
        const first = list.findIndex(i => i?.kind === "app");
        const last = list.length - 1 - [...list].reverse().findIndex(i => i?.kind === "app");
        return first < 0 ? [-1, -1] : [first, last];
    }

    // What `pinned` becomes when the tile at `from` in `items` is dragged to
    // `to`, or null when nothing changes. The applications kept in the dock
    // take the order they now have on it. A running one that is not kept
    // joins them when it is dropped among them or straight after the last of
    // them; a kept one stays kept wherever it lands, after the others if it
    // is dropped among the running ones. Kept ids the dock is not showing (an
    // application since removed) stay in the list, after the rest.
    function reorder(items, pinned, from, to) {
        const list = items ?? [];
        if (from === to || !root.draggable(list[from]) || list[to]?.kind !== "app")
            return null;
        const key = String(list[from].appKey);
        const apps = list.filter(i => i?.kind === "app").map(i => String(i.appKey ?? ""));
        const pins = (pinned ?? []).map(p => String(p)).filter(p => p.length > 0);
        const kept = new Set(pins);
        const keptShown = apps.filter(k => kept.has(k)).length;
        const at = apps.indexOf(key) + (to - from);
        const order = apps.filter(k => k !== key);
        order.splice(at, 0, key);
        const joins = kept.has(key) || at <= keptShown;
        const next = order.filter(k => k.length > 0 && (kept.has(k) || (k === key && joins)))
            .concat(pins.filter(p => apps.indexOf(p) < 0));
        return next.join("\n") === pins.join("\n") ? null : next;
    }

    // Where each tile's centre sits along the dock at rest, from the start of
    // the first tile: `lengths` are the tiles' lengths along the dock, `gap`
    // the space between two.
    function restCentres(lengths, gap) {
        let at = 0;
        return (lengths ?? []).map(len => {
            const centre = at + len / 2;
            at += len + gap;
            return centre;
        });
    }

    // How much bigger each tile is drawn, for `dock.magnify`: the one under
    // the pointer `peak` times its size, the ones within `reach` of it less,
    // falling away on a cosine, and the rest at 1. `centres` and `pointer`
    // are measured along the dock at rest (restCentres), so a tile growing
    // does not move what the pointer is measured against; a pointer that is
    // not a number is nowhere, and nothing grows.
    function magnify(centres, pointer, peak, reach) {
        const list = centres ?? [];
        const extra = Math.max(0, Number(peak) - 1);
        if (!Number.isFinite(pointer) || !(extra > 0) || !(reach > 0))
            return list.map(c => 1);
        return list.map(c => {
            const t = Math.abs(c - pointer) / reach;
            return t >= 1 ? 1 : 1 + extra * (1 + Math.cos(Math.PI * t)) / 2;
        });
    }

    // Where a point `at` along the dock at rest is drawn once the tiles are
    // grown by `scales`: inside a tile it stretches with the tile, in a gap
    // it keeps its distance from the tile before it, and before the first
    // tile or past the last it keeps its distance from that one. The dock
    // puts the pointer's point under the pointer, so the tile it is on stays
    // under it as the tiles round it grow.
    function stretched(lengths, scales, gap, at) {
        const lens = lengths ?? [];
        const grows = scales ?? [];
        if (!(at > 0))
            return Number(at) || 0;
        let rest = 0;
        let shown = 0;
        for (let i = 0; i < lens.length; i++) {
            const grow = grows[i] ?? 1;
            if (at <= rest + lens[i])
                return shown + (at - rest) * grow;
            rest += lens[i] + gap;
            shown += lens[i] * grow + gap;
            if (at <= rest)
                return shown - (rest - at);
        }
        return shown + (at - rest);
    }

    // Whether the dock is out of the way right now, for `dock.visibility`:
    //   always  never hidden, and windows stop above it
    //   autohide hidden until the pointer reaches its edge
    //   dodge   hidden while a window reaches into its space
    // It always shows while the pointer is on it or its menu is open.
    readonly property var _hides: ({
        always: s => false,
        autohide: s => true,
        dodge: s => s.windowNear === true
    })

    function hidden(visibility, state) {
        const s = state ?? {};
        if (s.pointerInside === true || s.menuOpen === true)
            return false;
        const rule = root._hides[visibility] ?? root._hides.always;
        return rule(s);
    }

    // How deep the strip along the screen's edge is that takes the pointer
    // for a dock that can hide, in pixels; 0 for one that never does. Hidden,
    // a sliver to come back from. Shown, the gap between the edge and the
    // glass (`margin`), all along the edge: a pointer resting at the edge is
    // then still on the dock, so it neither hides under the pointer nor
    // comes straight back, again and again.
    readonly property int edgeSliver: 3

    function edgeDepth(visibility, hidden, margin) {
        if (!root._hides[visibility] || visibility === "always")
            return 0;
        if (hidden)
            return root.edgeSliver;
        return Math.max(root.edgeSliver, Number(margin) || 0);
    }
}
