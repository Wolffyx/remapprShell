pragma Singleton

// Putting a small surface where the pointer is, and keeping it on the screen.
//
// Pure, and a leaf module of its own so the tests can load it. A menu that
// opens under the pointer is arithmetic with one interesting case -- the
// pointer near an edge -- and that is exactly the case nobody can test by
// hand on the monitor they happen to have.
//
// Coordinates come from KWin, which numbers every screen in one space: a
// second monitor to the right of a 2560-wide one starts at x 2560. A layer
// surface is placed in its *own* screen's coordinates, so the screen's own
// origin is taken off first.

import QtQuick

QtObject {
    id: root

    // { x, y } for the top-left of a `width` x `height` surface opened at
    // (pointerX, pointerY), in the screen's own coordinates.
    //
    //   - it opens down and to the right of the pointer, as every menu does
    //   - `gap` is how far from the pointer it sits
    //   - near the right or bottom edge it flips to the other side of the
    //     pointer rather than hanging off the screen
    //   - and if it is too big to fit either way, it is pushed inside the
    //     screen and left there: a surface partly off the screen is worse
    //     than one not quite where the pointer is
    function atPointer(pointerX, pointerY, screen, width, height, gap) {
        const g = Number(gap) || 0;
        const sx = Number(screen?.x) || 0;
        const sy = Number(screen?.y) || 0;
        const sw = Number(screen?.width) || 0;
        const sh = Number(screen?.height) || 0;
        const w = Number(width) || 0;
        const h = Number(height) || 0;

        // Into the screen's own coordinates.
        let x = (Number(pointerX) || 0) - sx + g;
        let y = (Number(pointerY) || 0) - sy + g;

        if (x + w > sw)
            x = (Number(pointerX) || 0) - sx - w - g;
        if (y + h > sh)
            y = (Number(pointerY) || 0) - sy - h - g;

        x = Math.max(0, Math.min(x, Math.max(0, sw - w)));
        y = Math.max(0, Math.min(y, Math.max(0, sh - h)));
        return { x: Math.round(x), y: Math.round(y) };
    }

    // Whether a point is on a screen, both given in the compositor's
    // coordinates. Used to pick which screen a surface opens on when the
    // output the pointer was over is not known by name.
    function contains(screen, x, y) {
        const sx = Number(screen?.x) || 0;
        const sy = Number(screen?.y) || 0;
        return Number(x) >= sx && Number(x) < sx + (Number(screen?.width) || 0)
            && Number(y) >= sy && Number(y) < sy + (Number(screen?.height) || 0);
    }
}
