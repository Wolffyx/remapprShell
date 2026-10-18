/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The snap layouts, as data, and everything about them that is arithmetic:
    the zones each one has, how the panel of them is laid out, which zone a
    point is over, where an arrow key goes, how Snap Assist lays out the
    windows it offers, and -- the one part that touches KWin -- turning a
    screen's tiles into a layout and finding the tile for a zone.

    No QML and nothing of KWin's is imported, so tests/tst_SnapLayouts.qml
    reads this file as it is. The tile functions take whatever they are given
    that answers to `tiles`, `relativeGeometry`, `split()` and `remove()`.
*/
.pragma library

// A layout is a tree. A node splits its box one way -- "h" side by side, "v"
// one above the other -- into parts, each a fraction of that box: a number
// is a zone, an object is a box split again the other way. The six are the
// six Windows 11 offers on a wide screen, in its order.
const PRESETS = [
    { id: "halves",     tree: { dir: "h", parts: [1 / 2, 1 / 2] } },
    { id: "twoThirds",  tree: { dir: "h", parts: [2 / 3, 1 / 3] } },
    { id: "thirds",     tree: { dir: "h", parts: [1 / 3, 1 / 3, 1 / 3] } },
    { id: "mainStack",  tree: { dir: "h", parts: [1 / 2, { size: 1 / 2, dir: "v", parts: [1 / 2, 1 / 2] }] } },
    { id: "quarters",   tree: { dir: "h", parts: [{ size: 1 / 2, dir: "v", parts: [1 / 2, 1 / 2] },
                                                  { size: 1 / 2, dir: "v", parts: [1 / 2, 1 / 2] }] } },
    { id: "wideCentre", tree: { dir: "h", parts: [1 / 4, 1 / 2, 1 / 4] } }
];

// Two zones closer than this, edge for edge, are the same zone. KWin keeps a
// tile's place as a fraction, and a third does not survive the round trip
// exactly.
const EPSILON = 0.01;

function sizeOf(part) {
    return typeof part === "number" ? part : part.size;
}

function rect(x, y, width, height) {
    return { x: x, y: y, width: width, height: height };
}

// The same layout turned on its side, for a screen taller than it is wide:
// halves become top and bottom, as Windows does on a portrait screen.
function transpose(node) {
    if (typeof node === "number")
        return node;
    return {
        size: node.size,
        dir: node.dir === "h" ? "v" : "h",
        parts: node.parts.map(transpose)
    };
}

// The box of each part of a node, in order.
function boxes(node, box) {
    const out = [];
    let offset = 0;
    for (const part of node.parts) {
        const size = sizeOf(part);
        out.push(node.dir === "h"
            ? rect(box.x + offset * box.width, box.y, size * box.width, box.height)
            : rect(box.x, box.y + offset * box.height, box.width, size * box.height));
        offset += size;
    }
    return out;
}

// Every zone of a layout, depth first, as fractions of the screen.
function zonesOf(node, box) {
    const within = box || rect(0, 0, 1, 1);
    const parts = boxes(node, within);
    let out = [];
    node.parts.forEach((part, i) => {
        out = out.concat(typeof part === "number" ? [parts[i]] : zonesOf(part, parts[i]));
    });
    return out;
}

// The presets for a screen of this shape, each with its zones worked out.
function presets(portrait) {
    return PRESETS.map(p => {
        const tree = portrait ? transpose(p.tree) : p.tree;
        return { id: p.id, tree: tree, zones: zonesOf(tree) };
    });
}

function close(a, b) {
    return Math.abs(a.x - b.x) < EPSILON && Math.abs(a.y - b.y) < EPSILON
        && Math.abs(a.width - b.width) < EPSILON && Math.abs(a.height - b.height) < EPSILON;
}

// The same zones, in any order.
function sameZones(a, b) {
    return a.length === b.length && a.every(z => b.some(w => close(z, w)));
}

// The panel: a grid of cards, one a layout, each the shape of the screen.
//
//   aspect   the screen's width over its height
//   metrics  { card, gapX, gapY, pad, inset }: the longer side of a card,
//            the gaps between cards, the panel's own padding, and the space
//            around each zone inside its card
//
// Gives { width, height, cards: [{ x, y, width, height, zones: [...] }] } in
// the panel's own pixels, every zone rounded so neighbours share an edge.
function arrange(layouts, aspect, metrics) {
    const count = layouts.length;
    const columns = count <= 3 ? count : count <= 6 ? 3 : 4;
    const rows = Math.ceil(count / Math.max(1, columns));
    const cardW = Math.round(aspect >= 1 ? metrics.card : metrics.card * aspect);
    const cardH = Math.round(aspect >= 1 ? metrics.card / aspect : metrics.card);
    const inset = metrics.inset;

    const cards = layouts.map((layout, i) => {
        const x = metrics.pad + (i % columns) * (cardW + metrics.gapX);
        const y = metrics.pad + Math.floor(i / columns) * (cardH + metrics.gapY);
        const zones = layout.zones.map(z => {
            const left = Math.round(z.x * cardW), top = Math.round(z.y * cardH);
            const right = Math.round((z.x + z.width) * cardW), bottom = Math.round((z.y + z.height) * cardH);
            return rect(x + left + inset, y + top + inset, right - left - 2 * inset, bottom - top - 2 * inset);
        });
        return { x: x, y: y, width: cardW, height: cardH, zones: zones };
    });

    return {
        width: 2 * metrics.pad + columns * cardW + Math.max(0, columns - 1) * metrics.gapX,
        height: 2 * metrics.pad + rows * cardH + Math.max(0, rows - 1) * metrics.gapY,
        cards: cards
    };
}

function inside(r, x, y, margin) {
    const m = margin || 0;
    return x >= r.x - m && x < r.x + r.width + m && y >= r.y - m && y < r.y + r.height + m;
}

// The zone under a point of the panel, as { layout, zone }, or null. The
// space between two zones of a card belongs to the nearer of them, so
// nothing inside a card is a gap to fall through.
function hit(arrangement, x, y, inset) {
    for (let i = 0; i < arrangement.cards.length; ++i) {
        const card = arrangement.cards[i];
        if (!inside(card, x, y))
            continue;
        for (let j = 0; j < card.zones.length; ++j) {
            if (inside(card.zones[j], x, y, inset))
                return { layout: i, zone: j };
        }
    }
    return null;
}

function sameHit(a, b) {
    return a === b || (!!a && !!b && a.layout === b.layout && a.zone === b.zone);
}

// A zone, from fractions of an area to that area's pixels.
function place(zone, area) {
    return rect(Math.round(area.x + zone.x * area.width), Math.round(area.y + zone.y * area.height),
                Math.round(zone.width * area.width), Math.round(zone.height * area.height));
}

// ---- KWin's tiles ----------------------------------------------------------
//
// A screen's tiles are a tree too, and the same shape: a tile is split one
// way into children, each placed by `relativeGeometry` -- a fraction of the
// whole screen, not of its parent. The leaves are where windows go.

function childrenOf(tile) {
    return Array.from(tile.tiles || []);
}

function leaves(tile) {
    const kids = childrenOf(tile);
    if (kids.length === 0)
        return [tile];
    let out = [];
    for (const kid of kids)
        out = out.concat(leaves(kid));
    return out;
}

// A QRectF for a property that takes one. QML converts a plain object for a
// rect property only sometimes; `Qt.rect` always works where there is a Qt.
function asRect(r) {
    return typeof Qt !== "undefined" && Qt.rect ? Qt.rect(r.x, r.y, r.width, r.height) : r;
}

function geometryOf(tile) {
    const g = tile.relativeGeometry;
    return rect(g.x, g.y, g.width, g.height);
}

// The zones a screen's tiles make now. A screen nobody has tiled is one tile,
// which is no layout at all.
function tileZones(root) {
    const found = leaves(root);
    return found.length < 2 ? [] : found.map(geometryOf);
}

function leafFor(root, zone) {
    return leaves(root).find(t => close(geometryOf(t), zone)) || null;
}

// Gives a tile the shape of a node, splitting it as KWin's own tile editor
// does. Splitting a leaf makes two children; splitting the last child again
// the same way adds a third beside it. Then each child is sized, first to
// last: KWin moves a child's neighbour along with the edge they share, so
// sizing them in order leaves every one where it should be.
function grow(tile, node, box, directions) {
    const dir = directions[node.dir];
    tile.split(dir);
    while (childrenOf(tile).length < node.parts.length) {
        const kids = childrenOf(tile);
        const before = kids.length;
        kids[kids.length - 1].split(dir);
        if (childrenOf(tile).length === before)
            return false;
    }
    const kids = childrenOf(tile);
    const parts = boxes(node, box);
    parts.forEach((part, i) => kids[i].relativeGeometry = asRect(part));
    return node.parts.every((part, i) => typeof part === "number" || grow(kids[i], part, parts[i], directions));
}

// A window into a tile, and out of one. KWin 6.8 has the tile do it, and
// says writing `window.tile` is deprecated; a KWin before it has only that.
function manage(tile, w) {
    if (typeof tile.manage === "function")
        tile.manage(w);
    else
        w.tile = tile;
}

function unmanage(tile, w) {
    if (typeof tile.unmanage === "function")
        tile.unmanage(w);
    else
        w.tile = null;
}

// The windows in a tile: its own list where it keeps one, and otherwise
// every window that names it.
function windowsIn(tile, windows) {
    return tile.windows !== undefined ? Array.from(tile.windows) : windows.filter(w => w.tile === tile);
}

// Every window in a screen's tiles, out of them and left where it is. KWin
// hands the windows of a tile it removes to the tile above it -- which for a
// layout of one level is the whole screen, so a window snapped to the left
// half came back filling the screen when another was snapped into thirds.
// Windows 11 leaves a window snapped before where it was, and so does this.
function release(root) {
    for (const leaf of leaves(root)) {
        for (const w of Array.from(leaf.windows || [])) {
            const g = w.frameGeometry;
            const kept = rect(g.x, g.y, g.width, g.height);
            unmanage(leaf, w);
            w.frameGeometry = asRect(kept);
        }
    }
}

// Makes a screen's tiles a layout, unless they already are one: windows in
// the tiles that stay keep them. `directions` is KWin's numbering of its
// layout directions, { h, v }. False when KWin did not split as asked.
function build(root, tree, directions) {
    if (sameZones(tileZones(root), zonesOf(tree)))
        return true;
    release(root);
    for (const kid of childrenOf(root).reverse())
        kid.remove();
    return grow(root, tree, rect(0, 0, 1, 1), directions);
}

// ---- the keyboard, and Snap Assist ------------------------------------------

// Every zone of the panel, card by card, each with the layout and zone it is
// -- the list the arrow keys move through.
function zoneList(arrangement) {
    let out = [];
    arrangement.cards.forEach((card, i) => {
        out = out.concat(card.zones.map((z, j) => ({ layout: i, zone: j, rect: z })));
    });
    return out;
}

function centre(r) {
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
}

// For each arrow, how far a point is that way, and how far off to the side.
const AXES = {
    left:  { along: c => -c.x, across: c => c.y },
    right: { along: c => c.x,  across: c => c.y },
    up:    { along: c => -c.y, across: c => c.x },
    down:  { along: c => c.y,  across: c => c.x }
};

// Where an arrow key goes from rects[from]: the nearest rect whose centre is
// that way, a step to the side counting double -- so Right from the top of a
// stack goes to the top of the card beside it, not to its bottom. `from`
// itself when nothing is that way.
function nearest(rects, from, direction) {
    const axis = AXES[direction];
    if (!axis || from < 0 || from >= rects.length)
        return from;
    const here = centre(rects[from]);
    let best = from;
    let bestScore = Infinity;
    rects.forEach((r, i) => {
        const c = centre(r);
        const along = axis.along(c) - axis.along(here);
        const score = along + 2 * Math.abs(axis.across(c) - axis.across(here));
        if (i !== from && along >= 0.5 && score < bestScore) {
            best = i;
            bestScore = score;
        }
    });
    return best;
}

// Snap Assist's grid: `count` windows in a box, as cells of one size -- a
// picture of the shape `metrics.aspect` over a line `metrics.label` high for
// the title -- as large as fit and no wider than `metrics.cell`, `gap` apart
// and `pad` in from the box, each row centred. The number of columns is
// whichever gives the largest cells, the fewer on a tie.
//
// Gives { columns, cells: [rect...] } in the box's own coordinates.
function grid(count, box, metrics) {
    if (count <= 0)
        return { columns: 0, cells: [] };
    let best = null;
    for (let columns = 1; columns <= count; ++columns) {
        const rows = Math.ceil(count / columns);
        const byWidth = (box.width - 2 * metrics.pad - (columns - 1) * metrics.gap) / columns;
        const byHeight = ((box.height - 2 * metrics.pad - (rows - 1) * metrics.gap) / rows - metrics.label) * metrics.aspect;
        const width = Math.floor(Math.min(metrics.cell, byWidth, byHeight));
        if (!best || width > best.width)
            best = { columns: columns, rows: rows, width: width };
    }
    const w = Math.max(1, best.width);
    const h = Math.round(w / metrics.aspect) + metrics.label;
    const top = box.y + (box.height - best.rows * h - (best.rows - 1) * metrics.gap) / 2;
    const cells = [];
    for (let i = 0; i < count; ++i) {
        const row = Math.floor(i / best.columns);
        const inRow = Math.min(best.columns, count - row * best.columns);
        const left = box.x + (box.width - inRow * w - (inRow - 1) * metrics.gap) / 2;
        cells.push(rect(Math.round(left + (i % best.columns) * (w + metrics.gap)),
                        Math.round(top + row * (h + metrics.gap)), w, h));
    }
    return { columns: best.columns, cells: cells };
}

// Two rects in pixels within `tolerance` of each other, edge for edge: a
// window where KWin has no tiles is in a zone when it is at the zone's place.
function matches(a, b, tolerance) {
    return Math.abs(a.x - b.x) <= tolerance && Math.abs(a.y - b.y) <= tolerance
        && Math.abs(a.width - b.width) <= tolerance && Math.abs(a.height - b.height) <= tolerance;
}
