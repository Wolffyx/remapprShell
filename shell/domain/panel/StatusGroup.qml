pragma Singleton

// The status glyphs as one button, or one widget each: the change the
// Taskbar page's "Status icons" switch makes to `bar.entries`.
//
// The panel has had both all along -- the network, Bluetooth, brightness,
// volume and battery widgets, and the quick settings (`status`), which draws
// the same glyphs as one target with the settings behind it. Choosing between
// them used to mean taking five widgets off on the Widgets page and putting
// one on. This does it in one go, both ways, and keeps the place and the
// order: grouping puts the button where the first glyph was and remembers
// which glyphs it holds in `widgets.status.parts`; separating puts those
// widgets back where the button was.
//
// The privacy indicator stays a widget of its own either way: something
// recording is news, not state. Pure, so it is tested (tst_StatusGroup).

import QtQuick

QtObject {
    id: root

    // The widgets the button can stand for, in the order it draws them.
    readonly property var parts: ["network", "bluetooth", "brightness", "volume", "battery"]

    // What the button holds when nothing says otherwise: the glyphs Windows
    // draws in its quick settings.
    readonly property var defaultParts: ["bluetooth", "network", "brightness", "volume", "battery"]

    function _on(e) {
        return !!e && e.enabled !== false;
    }

    // Whether the panel carries the quick settings button.
    function grouped(entries) {
        return (entries ?? []).some(e => root._on(e) && e.id === "status");
    }

    // { entries, parts }: the glyph widgets taken off and one `status` in
    // the place of the first, holding them in their order. With none on the
    // panel, the button goes at the end of the right-hand zone holding the
    // default glyphs. Already grouped: unchanged.
    function group(entries) {
        const list = (entries ?? []).filter(e => !!e);
        if (root.grouped(list))
            return { entries: list, parts: null };
        const taken = list.filter(e => root._on(e) && root.parts.indexOf(e.id) >= 0);
        const button = { id: "status", zone: taken[0]?.zone ?? "right", enabled: true };
        if (taken.length === 0)
            return { entries: list.concat([button]), parts: root.defaultParts };
        const at = list.indexOf(taken[0]);
        const rest = list.filter(e => taken.indexOf(e) < 0);
        const before = rest.filter(e => list.indexOf(e) < at);
        const after = rest.filter(e => list.indexOf(e) > at);
        return { entries: before.concat([button], after), parts: taken.map(e => e.id) };
    }

    // The `status` button taken off and, in its place, a widget for each
    // glyph it held (`parts`, its `widgets.status.parts`), skipping any that
    // are on the panel already. Not grouped: unchanged.
    function separate(entries, parts) {
        const list = (entries ?? []).filter(e => !!e);
        const button = list.find(e => root._on(e) && e.id === "status");
        if (!button)
            return list;
        const held = (Array.isArray(parts) ? parts : root.defaultParts).filter(id => root.parts.indexOf(id) >= 0);
        const there = list.filter(e => root._on(e)).map(e => e.id);
        const back = held.filter(id => there.indexOf(id) < 0).map(id => ({ id: id, zone: button.zone, enabled: true }));
        const at = list.indexOf(button);
        return list.slice(0, at).concat(back, list.slice(at + 1));
    }
}
