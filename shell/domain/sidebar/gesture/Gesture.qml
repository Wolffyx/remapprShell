pragma Singleton

// The arithmetic of opening the sidebar from its edge.
//
// Pure, and a leaf module of its own so the tests can load it. Two things are
// worked out here, and both are the kind of thing nobody can test by hand on
// the monitor they happen to have:
//
//   - where the grip goes: where the pointer was pushed into the edge, kept
//     on the screen. The grip is short on purpose -- a strip the height of
//     the screen took the last pixels of every scrollbar down that edge for
//     as long as it was lit, and was more than anyone needed to see
//   - how far a pull has brought the sidebar out, and whether letting go
//     leaves it open: past a third of the way, or flicked inwards
//
// Coordinates from KWin number every screen in one space; a surface is placed
// in its own screen's, so the screen's origin is taken off first.

import QtQuick

QtObject {
    id: root

    // How far a press has to move inwards before the sidebar starts to follow
    // it: far enough that a click at the edge is not a pull.
    readonly property int deadZone: 6

    // Let go past this much of the way out, and it stays open.
    readonly property real openAt: 0.35

    // Or flicked at this many pixels a second, inwards to open, outwards to
    // put it back -- whichever way it is.
    readonly property int flick: 600

    // The middle of a grip `length` long, in the surface's own coordinates:
    // where the pointer was pushed in, kept wholly on a surface `height` tall.
    // A pointer that was not reported (-1) puts it in the middle.
    function gripCentre(pointerY, screenY, height, length) {
        const h = Math.max(0, Number(height) || 0);
        const half = Math.min(h / 2, Math.max(0, Number(length) || 0) / 2);
        const py = Number(pointerY);
        if (!(py >= 0))
            return Math.round(h / 2);
        const local = py - (Number(screenY) || 0);
        return Math.round(Math.max(half, Math.min(h - half, local)));
    }

    // The part of the edge that takes a press while the grip is lit: the grip
    // and `slack` either side of it, no further than the surface.
    function band(centre, length, slack, height) {
        const h = Math.max(0, Number(height) || 0);
        const reach = (Math.max(0, Number(length) || 0) / 2) + Math.max(0, Number(slack) || 0);
        const top = Math.max(0, Math.round((Number(centre) || 0) - reach));
        const bottom = Math.min(h, Math.round((Number(centre) || 0) + reach));
        return { y: top, height: Math.max(0, bottom - top) };
    }

    // A horizontal movement as a distance inwards: away from the left edge is
    // to the right, away from the right edge to the left.
    function inward(dx, leftEdge) {
        const d = Number(dx) || 0;
        return leftEdge ? d : -d;
    }

    // How far out the sidebar is, 0 to 1, for a pull `pulled` pixels inwards
    // once the dead zone is passed. `travel` is how far it moves to be all
    // the way out: its width and its margin.
    function progress(pulled, travel) {
        const t = Number(travel) || 0;
        if (t <= 0)
            return 1;
        const p = ((Number(pulled) || 0) - root.deadZone) / t;
        return Math.max(0, Math.min(1, p));
    }

    // Whether letting go at `progress`, moving `velocity` pixels a second
    // inwards (negative: outwards), leaves the sidebar open.
    function settlesOpen(progress, velocity) {
        const v = Number(velocity) || 0;
        if (v <= -root.flick)
            return false;
        if (v >= root.flick && (Number(progress) || 0) > 0)
            return true;
        return (Number(progress) || 0) >= root.openAt;
    }

    // How far from where it rests the sidebar is drawn, `shown` of the way
    // out: towards its own edge, by as much as it travels.
    function offset(shown, travel, leftEdge) {
        const s = Math.max(0, Math.min(1, Number(shown) || 0));
        const away = (1 - s) * Math.max(0, Number(travel) || 0);
        return leftEdge ? -away : away;
    }

    // The screen an edge was pushed on, by the name KWin gave its output, and
    // by the point when the name did not come through. Empty when neither
    // finds one, which is the first screen to whoever asks.
    function screenFor(output, x, y, screens) {
        const list = screens ?? [];
        const name = String(output ?? "");
        if (name.length > 0 && list.some(s => s?.name === name))
            return name;
        const px = Number(x);
        const py = Number(y);
        if (!(px >= 0) || !(py >= 0))
            return "";
        const hit = list.find(s => s && px >= s.x && px < s.x + s.width && py >= s.y && py < s.y + s.height);
        return hit ? String(hit.name) : "";
    }
}
