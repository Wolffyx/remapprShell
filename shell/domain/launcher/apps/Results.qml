pragma Singleton

// Putting the search's several sources into one list.
//
// Pure, and a module of its own so the tests can load it: everything here is
// arithmetic on candidates, and the candidates themselves come from the
// provider, which reads applications, windows, files and the settings schema.
//
// The problem it solves is that "best first" and "grouped" pull against each
// other. A list sorted purely by score puts a window between two applications
// and reads as noise; a list grouped first and scored inside each group hides
// the best match under a heading. So: score decides *what is in* the list,
// grouping decides *how it is ordered* once chosen. The best match is always
// present, and the rows are always readable.
//
// A group is also what keeps the keyboard honest -- the list stays flat, so
// the selection is still an index, and Up and Down still step one row.

import QtQuick

QtObject {
    id: root

    // The order groups appear in, whatever they scored. Applications first
    // because that is what a launcher is for; the shell's own settings last
    // because nobody searches for them twice.
    readonly property var order: ["app", "window", "file", "setting", "action"]

    // Most rows a *secondary* source may take, so that forty open windows
    // cannot push every application off the list. Deliberately not a setting:
    // it is a consequence of the card's height, not a preference.
    //
    // Applications are not capped, and capping them was a real regression:
    // "termina" is a query whose whole answer is a list of terminals, and a
    // cap of four turned that into four terminals and three unrelated rows.
    // A search's primary source is limited by the card, not by a quota.
    readonly property int perGroup: 3

    function capOf(group) {
        return group === "app" ? Number.MAX_SAFE_INTEGER : root.perGroup;
    }

    function _rank(group) {
        const i = root.order.indexOf(group);
        return i < 0 ? root.order.length : i;
    }

    // candidates: [{ item, score, group }], best first or not -- this sorts.
    // Returns the items alone, ready to be drawn.
    function merge(candidates, max) {
        const limit = Math.max(1, Number(max ?? 8));

        // What is in the list: by score, and no more than a secondary
        // source's share of it. The cap is applied before the overall limit,
        // so one noisy source cannot fill the card -- and never to
        // applications, which are what the list is mostly for.
        const seen = {};
        const chosen = [];
        for (const c of root.byScore(candidates)) {
            const g = c.group ?? "app";
            seen[g] = (seen[g] ?? 0) + 1;
            if (seen[g] > root.capOf(g))
                continue;
            chosen.push(c);
            if (chosen.length >= limit)
                break;
        }

        // How it is ordered: by group, keeping the score order inside each.
        return chosen
            .map((c, i) => ({ c: c, i: i }))
            .sort((a, b) => {
                const ga = root._rank(a.c.group), gb = root._rank(b.c.group);
                return ga !== gb ? ga - gb : a.i - b.i;
            })
            .map(e => Object.assign({}, e.c.item, { group: e.c.group }));
    }

    // Pinned first, then best first, then by name so that an order does not
    // wobble between two equal results as unrelated things change.
    //
    // Pinning is ahead of the score rather than added to it because that is
    // what pinning means: somebody looked at a list of eight terminals and
    // said which one they meant. A score can only ever order results of the
    // same kind of match, so as a bonus a pin was invisible exactly when it
    // mattered -- a pinned editor under every application with "Editor" in
    // its name.
    function byScore(candidates) {
        return (candidates ?? []).slice().sort((a, b) => {
            if (!!a.pinned !== !!b.pinned)
                return a.pinned ? -1 : 1;
            if (a.score !== b.score)
                return b.score - a.score;
            return String(a.item?.name ?? "").localeCompare(String(b.item?.name ?? ""));
        });
    }

    // The heading a row carries, or "" when the row above it has the same
    // one. The card asks per row, so this takes the list and an index rather
    // than building a second model the selection would have to skip over.
    function headingAt(results, index) {
        const here = results?.[index]?.group ?? "";
        if (index <= 0)
            return root.label(here);
        return (results[index - 1]?.group ?? "") === here ? "" : root.label(here);
    }

    function label(group) {
        switch (group) {
        case "app":     return "Applications";
        case "window":  return "Open windows";
        case "file":    return "Recent files";
        case "setting": return "Settings";
        case "action":  return "Actions";
        case "sum":     return "Calculator";
        default:        return "";
        }
    }
}
