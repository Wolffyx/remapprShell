pragma Singleton

// How a section's keys are split into the cards a settings page draws.
//
// A page in this design is a set of named groups rather than one long list, so
// something has to decide which key belongs to which card. The rules are small
// and each one has a way of being wrong that is invisible in the code and
// obvious on screen:
//
//   * A group keeps the position of its first key, so the cards come in the
//     order the schema reads in. Filtering per group instead would order the
//     page by whichever group happened to be named first in the code.
//   * Keys that name no group share one card, and it comes first. They are the
//     section's plain settings; pushing them below the named groups would read
//     as an afterthought rather than as the subject.
//   * That first card is titled by the section, because a card with no label
//     above it and other labelled cards beside it looks like a mistake. A page
//     that would rather say nothing passes an empty title.
//   * A key whose group is the empty string is ungrouped, not a group named "".
//
// Pure, in a leaf module with no Quickshell import, so it is testable -- see
// scripts/lint-tests.sh for why that matters.

import QtQuick

QtObject {
    id: root

    // keys: { "path.to.key": { group, ... } }, in the schema's order.
    // Returns [{ label, keys: ["path.to.key", ...] }], in the page's order.
    function split(keys, title) {
        const out = [];
        const at = ({});
        for (const key of Object.keys(keys ?? {})) {
            const group = keys[key]?.group ?? "";
            if (at[group] === undefined) {
                at[group] = out.length;
                out.push({ label: group === "" ? (title ?? "") : group, keys: [] });
            }
            out[at[group]].keys.push(key);
        }
        return out;
    }
}
