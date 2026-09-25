pragma Singleton

// What the keyboard widget shows, as pure functions of what KWin reports: the
// layouts read off the bus, the label the panel draws for one, and which one a
// click or a wheel notch moves to.
//
// StatusIcons forwards to every function here, so a widget that asks it keeps
// working.

import QtQuick

QtObject {
    id: root

    // KWin's layouts as getLayoutsList gives them: [[shortName, displayName,
    // longName]]. The display name is the label a person gave the layout in
    // System Settings, and is usually empty.
    function keyboardLayouts(rows) {
        return (rows ?? [])
            .filter(r => Array.isArray(r) && r.length >= 3)
            .map(r => ({ short: String(r[0]), display: String(r[1]), long: String(r[2]) }));
    }

    // What the panel shows: the person's own label verbatim, or the short
    // name in capitals -- "US", "DE" -- as Plasma's applet does.
    function layoutLabel(layout) {
        if (!layout)
            return "";
        return layout.display || String(layout.short ?? "").toUpperCase();
    }

    // The index `steps` away from `index`, wrapping round both ends.
    function cycleIndex(index, count, steps) {
        if (!(count > 0))
            return -1;
        const from = index >= 0 && index < count ? index : 0;
        return ((from + steps) % count + count) % count;
    }
}
