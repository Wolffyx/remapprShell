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
}
