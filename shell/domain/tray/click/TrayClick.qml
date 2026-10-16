pragma Singleton

// A click on a tray icon: where on the screen it was, and which of the clicks
// waiting for a bus address a lookup can answer.
//
// Pure, and a leaf module of its own so the tests can load it --
// TrayActivation, which sends the click, needs the Quickshell runtime, and
// scripts/lint-tests.sh says why that would keep this untestable beside it.
//
// The place is what the StatusNotifierItem spec's Activate carries, and it is
// not decoration. JetBrains Toolbox opens its window at it. xembedsniproxy,
// which stands in for every old X11 tray icon, moves the icon's hidden window
// there before it clicks it, so the application's own window or menu opens
// where it thinks its icon is. A point at the origin sent all of them to the
// top-left corner of the layout, whatever KWin's placement policy said -- so
// the origin is never the answer while anything better is known.

import QtQuick

QtObject {
    id: root

    // Where a click on an icon was, as { x, y } in KWin's global coordinates.
    // Those number every screen in one space, and a screen left of or above
    // the first has a negative origin: the point keeps it, or it lands on the
    // neighbouring screen.
    //
    //   - the panel's `screen` ({ x, y, width, height }), its `position`
    //     (which edge), its `extent` (how far it reaches into the screen) and
    //     the icon's place in the panel's window (`local`, { x, y }) known:
    //     the icon's place along the panel, at the panel's inner edge -- which
    //     is where Plasma says too. The panel spans its screen edge to edge,
    //     so a position in its window is one on the screen
    //   - the screen known and the icon's place not: the middle of the screen
    //   - no screen: the middle of the first of `screens`, a place an
    //     application can open beside without opening in a corner
    //   - no screens at all: the origin, as there is nowhere else
    //
    // Whole pixels, as Activate takes integers.
    function point(screen, position, extent, local, screens) {
        if (!screen)
            return root.centre((screens ?? [])[0]);
        if (!local)
            return root.centre(screen);
        const inner = root._innerEdge[position] ?? root._innerEdge.bottom;
        const p = inner(root._rect(screen), Number(local.x) || 0, Number(local.y) || 0, Number(extent) || 0);
        return { x: Math.round(p.x), y: Math.round(p.y) };
    }

    // The middle of a screen, or the origin for none.
    function centre(screen) {
        if (!screen)
            return { x: 0, y: 0 };
        const s = root._rect(screen);
        return { x: Math.round(s.x + s.width / 2), y: Math.round(s.y + s.height / 2) };
    }

    // The icon's place along the panel at the panel's inner edge, for each
    // edge a panel can be on. A panel at the bottom is the default, as it is
    // the panel's.
    readonly property var _innerEdge: ({
        top: (s, x, y, extent) => ({ x: s.x + x, y: s.y + extent }),
        bottom: (s, x, y, extent) => ({ x: s.x + x, y: s.y + s.height - extent }),
        left: (s, x, y, extent) => ({ x: s.x + extent, y: s.y + y }),
        right: (s, x, y, extent) => ({ x: s.x + s.width - extent, y: s.y + y })
    })

    function _rect(screen) {
        return {
            x: Number(screen.x) || 0,
            y: Number(screen.y) || 0,
            width: Number(screen.width) || 0,
            height: Number(screen.height) || 0
        };
    }

    // The clicks of `waiting` that the lookup numbered `run` can answer, and
    // those that must wait for a later one: { due, waiting }, each in the
    // order the clicks were made.
    //
    // A click is made with `after`, the number of the last lookup started by
    // then. Only a lookup started after the click is due to answer it: one
    // that was already running read the watcher's list before the click, and
    // may not know its item at all -- an application that has just
    // registered. Answering from it sent that click to 0,0 when the lookup
    // queued behind it would have found the item.
    function due(waiting, run) {
        const now = [];
        const later = [];
        for (const w of waiting ?? []) {
            if (w.after < run)
                now.push(w);
            else
                later.push(w);
        }
        return { due: now, waiting: later };
    }
}
