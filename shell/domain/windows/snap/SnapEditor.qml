pragma Singleton

// The snap layout editor's arithmetic: a layout of the user's own drawn by
// splitting zones, merging them and dragging the edges between them.
//
// A layout is the tree kwin/snap's layouts.js reads -- { dir: "h"|"v",
// parts: [share | { size, dir, parts }] }, "h" side by side, each share a
// fraction of its box -- and every function here takes one and gives back a
// new one, never changing what it was given. The tree is kept in the one
// shape KWin's tiles can be built in: no split inside a split the same way
// (KWin's split() of such a tile adds a sibling, so it is folded into its
// parent) and no split of one part. And no zone of `minZone` of the screen
// or less either way, which KWin 6.8 will not make: nothing here makes one
// under `smallest`, a step more -- a split that would is refused, and an
// edge stops there.
//
// layouts.js is not imported: it is KWin's, in kwin/, and a copied install
// of the shell has nothing outside shell/. What the two must agree on --
// the presets, the smallest zone, the most layouts, and that every tree made
// here is one layouts.js takes -- tests/tst_SnapEditor.qml checks.
//
// Pure, and a module of its own so the tests can load it.

import QtQuick

QtObject {
    id: root

    // A tile KWin 6.8 will not make, a fraction of the screen a side: every
    // zone must be more (layouts.js's MIN_ZONE, measured).
    readonly property real minZone: 0.15
    // As many as the panel has room for (layouts.js's MAX_CUSTOM).
    readonly property int maxLayouts: 6
    // An edge dragged lands on a step of this, a fraction of the screen.
    readonly property real step: 0.005
    // The smallest zone drawn here: a step over KWin's.
    readonly property real smallest: root.minZone + root.step

    // The six the panel always has, to start a layout from: layouts.js's,
    // in its order.
    readonly property var presets: [
        { id: "halves",     label: "Halves",           tree: { dir: "h", parts: [1 / 2, 1 / 2] } },
        { id: "twoThirds",  label: "Two thirds",       tree: { dir: "h", parts: [2 / 3, 1 / 3] } },
        { id: "thirds",     label: "Thirds",           tree: { dir: "h", parts: [1 / 3, 1 / 3, 1 / 3] } },
        { id: "mainStack",  label: "One beside two",   tree: { dir: "h", parts: [1 / 2, { size: 1 / 2, dir: "v", parts: [1 / 2, 1 / 2] }] } },
        { id: "quarters",   label: "Quarters",         tree: { dir: "h", parts: [{ size: 1 / 2, dir: "v", parts: [1 / 2, 1 / 2] },
                                                                                { size: 1 / 2, dir: "v", parts: [1 / 2, 1 / 2] }] } },
        { id: "wideCentre", label: "Half between quarters", tree: { dir: "h", parts: [1 / 4, 1 / 2, 1 / 4] } }
    ]

    readonly property var unit: ({ x: 0, y: 0, width: 1, height: 1 })

    // One zone, the whole screen: where a layout drawn from nothing starts.
    // Not a layout until it is split.
    function blank() {
        return { dir: "h", parts: [1] };
    }

    function copy(tree) {
        return JSON.parse(JSON.stringify(tree));
    }

    function sizeOf(part) {
        return typeof part === "number" ? part : part.size;
    }

    function samePath(a, b) {
        return a.length === b.length && a.every((n, i) => n === b[i]);
    }

    // The box of each part of a node, as layouts.js's `boxes`.
    function boxes(node, box) {
        const out = [];
        let offset = 0;
        for (const part of node.parts) {
            const size = root.sizeOf(part);
            out.push(node.dir === "h"
                ? { x: box.x + offset * box.width, y: box.y, width: size * box.width, height: box.height }
                : { x: box.x, y: box.y + offset * box.height, width: box.width, height: size * box.height });
            offset += size;
        }
        return out;
    }

    // Every zone, depth first -- the order the panel numbers them in -- as
    // fractions of the screen, each with `path`: the index of its part at
    // each level down.
    function zones(tree) {
        return root.zonesIn(tree, root.unit, []);
    }

    function zonesIn(node, box, path) {
        let out = [];
        root.boxes(node, box).forEach((b, i) => {
            const part = node.parts[i];
            const here = path.concat([i]);
            out = out.concat(typeof part === "number"
                ? [Object.assign({ path: here }, b)] : root.zonesIn(part, b, here));
        });
        return out;
    }

    // A tree of two zones or more: something the panel can show.
    function isLayout(tree) {
        return root.zones(tree).length >= 2;
    }

    // The node at a path of indices.
    function nodeAt(tree, path) {
        return path.reduce((node, i) => node.parts[i], tree);
    }

    // ---- keeping the tree in KWin's shape -----------------------------------

    function resized(part, size) {
        return typeof part === "number" ? size : Object.assign({}, part, { size: size });
    }

    // A part as its parent holds it: a split of one part is that part, at
    // the split's size; a split the parent's way is its own parts, each its
    // share of the split's.
    function flatten(dir, part) {
        if (typeof part === "number")
            return [part];
        if (part.parts.length === 1)
            return root.flatten(dir, root.resized(part.parts[0], part.size));
        if (part.dir !== dir)
            return [part];
        return part.parts.map(p => root.resized(p, root.sizeOf(p) * part.size));
    }

    function fold(node) {
        let parts = [];
        for (const part of node.parts)
            parts = parts.concat(root.flatten(node.dir, typeof part === "number" ? part : root.fold(part)));
        return { size: node.size, dir: node.dir, parts: parts };
    }

    // The tree folded, and a whole screen split one way by a single split
    // the other way made that split.
    function normalise(tree) {
        let t = root.fold(tree);
        while (t.parts.length === 1 && typeof t.parts[0] !== "number")
            t = { dir: t.parts[0].dir, parts: t.parts[0].parts };
        return { dir: t.dir, parts: t.parts };
    }

    // Shares as JSON will keep them: six places, which no edge notices and
    // no validator minds.
    function tidy(tree) {
        const round = n => Math.round(n * 1e6) / 1e6;
        const walk = node => ({ size: node.size === undefined ? undefined : round(node.size), dir: node.dir,
                                parts: node.parts.map(p => typeof p === "number" ? round(p) : walk(p)) });
        return JSON.parse(JSON.stringify(walk(tree)));
    }

    // ---- splitting and merging ------------------------------------------------

    function zoneAt(tree, path) {
        return root.zones(tree).find(z => root.samePath(z.path, path)) || null;
    }

    // Whether a zone halved -- "h" into a left and a right, "v" a top and a
    // bottom -- leaves two zones KWin will make.
    function canSplit(tree, path, dir) {
        const zone = root.zoneAt(tree, path);
        if (!zone)
            return false;
        return (dir === "h" ? zone.width : zone.height) / 2 >= root.smallest - 1e-9;
    }

    function split(tree, path, dir) {
        if (!root.canSplit(tree, path, dir))
            return tree;
        const t = root.copy(tree);
        const parent = root.nodeAt(t, path.slice(0, -1));
        const i = path[path.length - 1];
        parent.parts[i] = { size: parent.parts[i], dir: dir, parts: [1 / 2, 1 / 2] };
        return root.normalise(t);
    }

    // The zone a merge gives its room to: the one before it in its split,
    // or after it when it is first.
    function neighbour(path) {
        const i = path[path.length - 1];
        return path.slice(0, -1).concat([i > 0 ? i - 1 : 1]);
    }

    function canMerge(tree, path) {
        return root.zones(tree).length > 1 && root.zoneAt(tree, path) !== null;
    }

    // A zone taken away, its room given to its neighbour in the same split
    // -- which, a split itself, grows along that way, every zone in it
    // larger and none smaller.
    function merge(tree, path) {
        if (!root.canMerge(tree, path))
            return tree;
        const t = root.copy(tree);
        const parent = root.nodeAt(t, path.slice(0, -1));
        const i = path[path.length - 1];
        const room = parent.parts[i];
        const j = i > 0 ? i - 1 : 0;
        parent.parts.splice(i, 1);
        parent.parts[j] = root.resized(parent.parts[j], root.sizeOf(parent.parts[j]) + room);
        return root.normalise(t);
    }

    // ---- the edges between zones ----------------------------------------------

    // How long a part must stay along one way, in fractions of the screen,
    // for none of its zones to be under `smallest` that way: a zone, that; a
    // split the other way, as long as its longest need; a split this way,
    // whatever its tightest part needs at the share that part has.
    function minExtent(part, dir) {
        if (typeof part === "number")
            return root.smallest;
        const needs = part.parts.map(p => root.minExtent(p, dir));
        if (part.dir !== dir)
            return Math.max(...needs);
        return Math.max(...part.parts.map((p, i) => needs[i] / root.sizeOf(p)));
    }

    // Every edge two parts of a split share, as a line: where it is
    // (`position`, along the split's way), the line's own rect, and how far
    // it can go each way (`lo`, `hi`) before a zone on either side is
    // under `smallest`. `path` and `index` say which split and which two parts.
    function edges(tree) {
        return root.edgesIn(tree, root.unit, []);
    }

    function edgesIn(node, box, path) {
        const parts = root.boxes(node, box);
        let out = [];
        for (let k = 0; k + 1 < parts.length; ++k)
            out.push(root.edgeOf(node, parts, k, path));
        node.parts.forEach((part, i) => {
            out = out.concat(typeof part === "number" ? [] : root.edgesIn(part, parts[i], path.concat([i])));
        });
        return out;
    }

    function edgeOf(node, parts, k, path) {
        const h = node.dir === "h";
        const a = parts[k], b = parts[k + 1];
        const start = h ? a.x : a.y;
        const end = h ? b.x + b.width : b.y + b.height;
        const position = h ? b.x : b.y;
        return {
            path: path, index: k, dir: node.dir, position: position,
            extent: h ? a.width / root.sizeOf(node.parts[k]) : a.height / root.sizeOf(node.parts[k]),
            lo: start + root.minExtent(node.parts[k], node.dir),
            hi: end - root.minExtent(node.parts[k + 1], node.dir),
            x: b.x, y: b.y, width: h ? 0 : b.width, height: h ? b.height : 0
        };
    }

    // An edge, as `edges` gave it for this tree, moved to `position` (a
    // fraction of the screen along its way): on a step, and no further than
    // lo or hi. Only the two parts either side of it change.
    function moveEdge(tree, edge, position) {
        const snapped = Math.round(position / root.step) * root.step;
        const to = Math.min(edge.hi, Math.max(edge.lo, snapped));
        const delta = (to - edge.position) / edge.extent;
        const t = root.copy(tree);
        const node = root.nodeAt(t, edge.path);
        const k = edge.index;
        node.parts[k] = root.resized(node.parts[k], root.sizeOf(node.parts[k]) + delta);
        node.parts[k + 1] = root.resized(node.parts[k + 1], root.sizeOf(node.parts[k + 1]) - delta);
        return t;
    }

    // ---- turning it --------------------------------------------------------

    // The same layout on its side: what a layout for any screen becomes on
    // a tall one, and what the editor does when it is changed to or from
    // tall screens only.
    function transpose(node) {
        if (typeof node === "number")
            return node;
        const turned = { dir: node.dir === "h" ? "v" : "h", parts: node.parts.map(p => root.transpose(p)) };
        return node.size === undefined ? turned : Object.assign({ size: node.size }, turned);
    }

    // Whether a layout for these screens is drawn on a tall screen.
    function tall(screen) {
        return screen === "tall";
    }
}
