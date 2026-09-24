pragma Singleton

// The bridge a popout takes the pointer across, from its widget to its card:
// the arithmetic, on its own.
//
// A hover card floats a gap clear of the panel, and the pointer going up from
// a taskbar button to its preview crossed that gap over nothing -- the one
// stretch of the way that was not the popout, so the card started closing
// under it. The popout's window reaches across the gap, and takes the pointer
// on a strip exactly as wide as the button, from the card's edge down to the
// panel's. Nothing of it is drawn: a visible neck was tried first, and was
// not wanted (2026-09-24).
//
// Named for the panel, as Placement is, so one set of rules covers all four
// edges:
//
//   along   the length of the panel, measured on the card from its leading
//           edge (its left on a top or bottom panel, its top on a side one)
//   depth   from the card's far edge towards the panel; the card's near edge
//           is at its thickness, and the panel's edge `span` beyond that
//
// Pure functions, tested in tests/tst_Tail.qml.

import QtQuick

QtObject {
    id: root

    // Where the bridge goes on a card `length` long along the panel: centred
    // on `at`, `width` wide, crossing `span` to the panel. A point past the
    // card's own ends is brought back onto it, so the bridge always meets the
    // card it leads to; one wider than the card is the card's width.
    function bridge(length, at, width, span) {
        const w = Math.max(0, Math.min(width, length));
        const c = Math.max(w / 2, Math.min(at, length - w / 2));
        return { at: c, width: w, span: Math.max(0, span) };
    }

    // A point given along and depth, on a card `w` x `h`, in the card's own
    // coordinates. The panel's side of the card is where depth runs out.
    function _map(edge, w, h, along, depth) {
        switch (edge) {
        case "top":
            return { x: along, y: h - depth };
        case "left":
            return { x: w - depth, y: along };
        case "right":
            return { x: depth, y: along };
        default:
            return { x: along, y: depth };
        }
    }

    function _horizontal(edge) {
        return edge !== "left" && edge !== "right";
    }

    // The rectangle the bridge occupies beyond the card's near edge, in the
    // card's coordinates plus (`ox`, `oy`).
    function box(b, w, h, edge, ox, oy) {
        const thick = root._horizontal(edge) ? h : w;
        const p = root._map(edge, w, h, b.at - b.width / 2, thick);
        const q = root._map(edge, w, h, b.at + b.width / 2, thick + b.span);
        return {
            x: Math.min(p.x, q.x) + (ox ?? 0),
            y: Math.min(p.y, q.y) + (oy ?? 0),
            width: Math.abs(q.x - p.x),
            height: Math.abs(q.y - p.y)
        };
    }
}
