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

    // A `set` key holds the chosen members of a fixed list. Turning one on or
    // off rebuilds that list from the schema's own order rather than appending
    // to what is stored -- otherwise turning a tile off and on again moves it
    // to the end of the grid, which is not what anybody meant by a switch.
    //
    // `chosen` being absent means every member: a machine that has never
    // touched the setting shows the lot, and so does one whose stored value
    // predates a member the schema has since gained.
    function chooseFrom(values, chosen, value, on) {
        const all = values ?? [];
        const now = Array.isArray(chosen) ? chosen : all;
        return all.filter(v => v === value ? on : now.indexOf(v) >= 0);
    }

    // A `list` key with `values` is the same choice, except that the order is
    // the person's: the sidebar draws its cards in the order the list gives.
    // So what is there keeps its place, a member turned off leaves, and one
    // turned on goes at the end. Anything stored that the schema does not
    // name is left alone rather than dropped.
    function chooseInOrder(values, chosen, value, on) {
        const now = Array.isArray(chosen) ? chosen.slice()
            : typeof chosen === "string" && chosen.length > 0 ? root.parseList(chosen, "items")
            : (values ?? []).slice();
        if (on && now.indexOf(value) >= 0)
            return now;
        const without = now.filter(v => v !== value);
        return on ? without.concat([value]) : without;
    }

    // A free `list` as one line of text, and back. `words` is a command line
    // -- split on spaces, with quotes keeping a spaced argument whole, because
    // a command is what those lists hold -- and anything else is items split
    // on commas. Empty pieces are dropped: a trailing comma is not an item.
    function parseList(text, mode) {
        const src = String(text ?? "");
        if (mode !== "words")
            return src.split(",").map(t => t.trim()).filter(t => t.length > 0);
        const out = [];
        let cur = "";
        let quote = "";
        let started = false;
        for (const ch of src) {
            if (quote) {
                if (ch === quote)
                    quote = "";
                else
                    cur += ch;
            } else if (ch === '"' || ch === "'") {
                quote = ch;
                started = true;
            } else if (/\s/.test(ch)) {
                if (started || cur.length > 0)
                    out.push(cur);
                cur = "";
                started = false;
            } else {
                cur += ch;
            }
        }
        if (started || cur.length > 0)
            out.push(cur);
        return out;
    }

    function formatList(list, mode) {
        if (!Array.isArray(list))
            return String(list ?? "");
        if (mode !== "words")
            return list.join(", ");
        return list.map(w => {
            const t = String(w);
            return t.length === 0 || /[\s"']/.test(t) ? `"${t.replace(/"/g, "'")}"` : t;
        }).join(" ");
    }
}
