pragma Singleton

// Which tray icons go where.
//
// Three states, and one function that decides them, used by both the panel and
// the settings page. They were computed separately at first, which is a
// standing invitation for the page to show one arrangement while the panel
// draws another -- and the user would have no way to tell which was lying.
//
// The rules, and the reason for each:
//
//   * `hidden` wins over everything. It means "I never want to see this", and
//     an id in both lists is a leftover, not a contradiction to resolve.
//   * An empty `pinned` means everything is on the panel. That is what makes a
//     fresh install useful: the alternative is an empty strip and a chevron
//     hiding the whole tray, which reads as broken.
//   * A pinned id that is not running is simply absent. An application that is
//     closed should not leave a gap where its icon was.
//   * Pinned order is the panel's order. Anything not pinned keeps the order
//     the host gives it, which is roughly the order things started.
//
// Pure, in a leaf module with no Quickshell import, so it is testable -- see
// scripts/lint-tests.sh for why that matters.

import QtQuick

QtObject {
    id: root

    // items: objects with an `id`. Returns { shown, overflow, hidden }, each a
    // list of the same objects.
    function split(items, pinned, hidden) {
        const all = (items ?? []).filter(i => i && i.id !== undefined);
        const pinnedIds = pinned ?? [];
        const hiddenIds = hidden ?? [];

        const out = { shown: [], overflow: [], hidden: [] };

        for (const item of all)
            if (hiddenIds.includes(item.id))
                out.hidden.push(item);

        const visible = all.filter(i => !hiddenIds.includes(i.id));

        if (pinnedIds.length === 0) {
            out.shown = visible;
            return out;
        }

        for (const id of pinnedIds) {
            const item = visible.find(i => i.id === id);
            if (item && !out.shown.includes(item))
                out.shown.push(item);
        }
        out.overflow = visible.filter(i => !out.shown.includes(i));
        return out;
    }

    // The ids of a split, in the same shape. What the settings page draws its
    // three lists from, so the page and the panel agree by construction.
    function splitIds(items, pinned, hidden) {
        const s = root.split(items, pinned, hidden);
        return {
            shown: s.shown.map(i => i.id),
            overflow: s.overflow.map(i => i.id),
            // Ids the user has hidden, including any that are not running --
            // those must stay on the page or they could never be brought back.
            hidden: (hidden ?? []).slice()
        };
    }
}
