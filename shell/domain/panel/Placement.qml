pragma Singleton

// Where a window beside the panel goes: the arithmetic, on its own.
//
// It lives here rather than inline in EdgeWindow because it is the part that
// keeps being wrong and the part that can be checked without a screen. Every
// placement bug this project has had was a number: a popout that opened at the
// screen's left edge whatever widget asked for it, a popout on a side panel
// that opened at the bottom, and a popout whose transparent border for its
// shadow reached back over the panel and swallowed the click meant for the
// button that opened it.
//
// Two directions, named for the panel rather than the screen, so one set of
// rules covers all four edges:
//
//   along   the length of the panel      -- x on a top or bottom panel
//   away    out from the screen's edge   -- y on a bottom panel

import QtQuick

QtObject {
    id: root

    // How far out from the screen's edge the *window* starts, so that what is
    // drawn in it sits clear of the whole of the panel's strip -- a floating
    // bar's own margin from the screen edge included.
    //
    // The window never reaches back over the panel. It used to, by the width
    // of the room it keeps for its shadow: a popout that carries an input mask
    // did not care, but the start menu cannot carry one (mask + exclusive
    // keyboard focus is a window KWin maps and never draws, see WidgetSlot),
    // so its window sat on the start button and the second click on it went
    // nowhere.
    //
    // Capping the room on that side was the first answer and it was wrong: the
    // shadow is then cut off square where the room runs out, and a card whose
    // bottom corners are a straight line is what that looks like. So the gap
    // opens up instead, to at least the shadow's reach. With no shadow -- the
    // default -- there is nothing to make room for and the gap is the gap.
    function away(extent, gap, shadowMargin) {
        return Math.max(0, extent + Math.max(gap, shadowMargin) - shadowMargin);
    }

    // Where the window starts along the panel.
    //
    //   "centre"  the card's middle on the point the slot pointed at, which is
    //             what a popout under an icon wants
    //   "start"   the card's near edge level with the slot's, which is what a
    //             menu wants: a start menu six hundred pixels wide centred on
    //             a fifty-pixel button reads as belonging to neither.
    //
    // Then kept on screen, measuring the card rather than the window: a popout
    // near either end would otherwise run off it, or sit with its shadow's
    // width of nothing against the edge.
    function along(align, slotStart, centre, size, extent, shadowMargin, edgeMargin) {
        const lo = Math.max(0, edgeMargin - shadowMargin);
        const hi = Math.max(lo, extent - size - lo);
        return Math.max(lo, Math.min(root._wanted(align, slotStart, centre, size, shadowMargin), hi));
    }

    function _wanted(align, slotStart, centre, size, shadowMargin) {
        return align === "start"
            ? slotStart - shadowMargin
            : slotStart + centre - size / 2;
    }

    // How far the card moves inside its own window once the window has been
    // pushed back on screen.
    //
    // A window cannot start at a negative position, so a popout whose shadow
    // room would hang off the screen loses that much of its alignment: the
    // start menu, its button twelve pixels from the corner and its shadow
    // wanting twenty-nine, opened seventeen pixels to the right of the button
    // it belongs to. Moving the card within the window instead costs nothing
    // -- the shadow on that side is off the screen and cannot be seen either
    // way -- and puts the corner back where it belongs.
    //
    // Never more than the room there is, or the card would leave the window.
    function shift(align, slotStart, centre, size, extent, shadowMargin, edgeMargin) {
        const wanted = root._wanted(align, slotStart, centre, size, shadowMargin);
        const placed = root.along(align, slotStart, centre, size, extent, shadowMargin, edgeMargin);
        return Math.max(-shadowMargin, Math.min(shadowMargin, Math.round(wanted - placed)));
    }
}
