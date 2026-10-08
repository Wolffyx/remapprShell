pragma Singleton

// What the sidebar is made of, and which of its cards are open.
//
// Pure, and a module of its own so the tests can load it: which cards exist,
// in which order a configured list draws them, and what folding one open or
// shut does to the remembered list. The sidebar itself only draws.
//
// Two lists decide it, both settings: `sidebar.cards` is which cards exist
// and in what order, `sidebar.expanded` is which of them are open. Keeping
// "open" in the configuration rather than in memory is what makes a sidebar
// opened for the third time today look the way it was left.

import QtQuick

QtObject {
    id: root

    // id, the heading it carries, and the glyph beside it. The order here is
    // the default order, and the ids are what the settings hold.
    readonly property var all: [
        { id: "media", title: "Playing", glyph: "music_note" },
        { id: "day", title: "Today", glyph: "calendar_month" },
        { id: "weather", title: "Weather", glyph: "partly_cloudy_day" },
        { id: "machine", title: "Machine", glyph: "memory" },
        { id: "notifications", title: "Notifications", glyph: "notifications" }
    ]

    function known(id) {
        return root.all.find(c => c.id === id) ?? null;
    }

    // The cards to draw, in order: whatever the setting lists, ignoring ids
    // this version does not have -- a card removed from a later release must
    // not leave a gap in somebody's sidebar. An empty or missing list means
    // all of them, because a sidebar with no cards in it is never what was
    // meant.
    function order(wanted) {
        const list = (wanted ?? []).map(id => root.known(String(id))).filter(c => c);
        return list.length > 0 ? list : root.all.slice();
    }

    function isOpen(expanded, id) {
        return (expanded ?? []).indexOf(String(id)) >= 0;
    }

    // The list with one card folded the other way. Returned rather than
    // mutated: the caller writes it to the configuration, and a list mutated
    // in place is a list nothing notices changing.
    function toggled(expanded, id) {
        const key = String(id);
        const list = (expanded ?? []).map(x => String(x));
        return root.isOpen(list, key) ? list.filter(x => x !== key) : list.concat([key]);
    }

    // Which side, as the surface wants it. Anything but "left" is the right,
    // which is where it has always been.
    function onLeft(position) {
        return String(position) === "left";
    }

    // The screen edge that opens a sidebar on this side, for `rmpr edges
    // shell`: the edge you push into is the side it comes from.
    function edgeFor(position) {
        return root.onLeft(position) ? "Left" : "Right";
    }
}
