/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Hyprland's dwindle layout, as arithmetic: a screen's tiled windows are a
    binary tree, and a window that comes splits the one it is given -- the
    focused one -- in two along its longer side, the newcomer taking the
    second half. A window that goes leaves its half to its sibling.

    A node is a window, { id }, or a split, { dir, ratio, a, b }: "h" puts
    `a` left of `b`, "v" above it, and `ratio` is `a`'s share. Every function
    here gives a new tree and leaves the one it was given alone, so a test can
    keep the old one to compare against.

    Hyprland's master layout is here too, as the same kind of tree: see
    `master`.

    No QML and nothing of KWin's, so tests/tst_Dwindle.qml reads this file as
    it is. Turning the tree into KWin's tiles is layouts.js's (`build`, the
    snap layouts' own, measured against KWin 6.8): `layout` here gives it the
    shape it takes.
*/
.pragma library

// The narrowest share a resize may leave either side of a split.
const MIN_RATIO = 0.05;

function leaf(id) {
    return { id: id };
}

function isLeaf(node) {
    return !!node && node.a === undefined;
}

function rect(x, y, width, height) {
    return { x: x, y: y, width: width, height: height };
}

// The two halves of a box, as a split divides it.
function halves(node, box) {
    if (node.dir === "h") {
        const w = box.width * node.ratio;
        return [rect(box.x, box.y, w, box.height), rect(box.x + w, box.y, box.width - w, box.height)];
    }
    const h = box.height * node.ratio;
    return [rect(box.x, box.y, box.width, h), rect(box.x, box.y + h, box.width, box.height - h)];
}

// Every window's place, as [{ id, rect }] in the order the tree has them
// (left before right, top before bottom), inside `box` -- the whole screen,
// in fractions, when none is given.
function places(node, box) {
    const within = box || rect(0, 0, 1, 1);
    if (!node)
        return [];
    if (isLeaf(node))
        return [{ id: node.id, rect: within }];
    const parts = halves(node, within);
    return places(node.a, parts[0]).concat(places(node.b, parts[1]));
}

function ids(node) {
    return places(node).map(p => p.id);
}

function contains(node, id) {
    return ids(node).indexOf(id) >= 0;
}

// The tree with one leaf swapped for whatever `replace` makes of it.
function mapLeaf(node, id, replace) {
    if (!node)
        return node;
    if (isLeaf(node))
        return node.id === id ? replace(node) : node;
    return { dir: node.dir, ratio: node.ratio, a: mapLeaf(node.a, id, replace), b: mapLeaf(node.b, id, replace) };
}

// How a split is made: `aspect`, the screen's width over its height; `min`,
// the smallest tile KWin makes, in fractions of the screen ({width,
// height}: KWin 6.8's is 0.15 a side, and past it KWin makes tiles that
// overlap and windows it never places -- measured in the rig, 2026-10-18);
// and `ratio`, the share of a split the window already there keeps. A bare
// number is the aspect alone, as the first callers passed it.
function shapeOf(shape) {
    const s = typeof shape === "number" || shape === undefined ? { aspect: shape } : shape;
    return {
        aspect: s.aspect || 1,
        min: s.min || { width: 0, height: 0 },
        ratio: s.ratio > 0 && s.ratio < 1 ? s.ratio : 0.5
    };
}

// Whether a box split along `dir` at `ratio` leaves both parts at least
// KWin's smallest tile.
function fits(r, dir, ratio, min) {
    const part = Math.min(ratio, 1 - ratio);
    return dir === "h" ? r.width * part >= min.width - 1e-9 : r.height * part >= min.height - 1e-9;
}

// The way to split a window's place: along its longer side in pixels, or
// the other way when that would be smaller than KWin allows. Null when
// neither fits.
function splitOf(p, s) {
    const longer = p.rect.width * s.aspect >= p.rect.height ? "h" : "v";
    const other = longer === "h" ? "v" : "h";
    const dir = [longer, other].find(d => fits(p.rect, d, s.ratio, s.min));
    return dir ? { at: p, dir: dir, ratio: s.ratio, first: false } : null;
}

// Where a newcomer goes: splitting `target` -- the last window when it is
// not in the tree -- or, when that one has no room left, the largest place
// that has. Null when no place has room.
function choose(all, target, s) {
    const at = all.find(p => p.id === target) || all[all.length - 1];
    const area = p => p.rect.width * s.aspect * p.rect.height;
    const rest = all.filter(p => p !== at).sort((x, y) => area(y) - area(x));
    for (const p of [at].concat(rest)) {
        const split = splitOf(p, s);
        if (split)
            return split;
    }
    return null;
}

// A window into the tree, splitting `target` along its longer side in
// pixels, which is why the shape's aspect is wanted: a half of a wide screen
// is a fraction wide and a fraction tall, and only the pixels say which is
// longer. `side`, when given, overrides both the direction and which half
// the newcomer gets: "left", "right", "up" or "down" of the target, in two
// equal halves. The tree as it was when there is no room for another
// window: the caller leaves that one floating.
function insert(node, id, target, shape, side) {
    if (!node)
        return leaf(id);
    if (contains(node, id))
        return node;
    const s = shapeOf(shape);
    const all = places(node);
    const split = side ? sideOf(all, target, side, s.min) : choose(all, target, s);
    if (!split)
        return node;
    return mapLeaf(node, split.at.id, old => ({
        dir: split.dir,
        ratio: split.ratio,
        a: split.first ? leaf(id) : old,
        b: split.first ? old : leaf(id)
    }));
}

function sideOf(all, target, side, min) {
    const at = all.find(p => p.id === target) || all[all.length - 1];
    const dir = side === "left" || side === "right" ? "h" : "v";
    if (!fits(at.rect, dir, 0.5, min))
        return null;
    return { at: at, dir: dir, ratio: 0.5, first: side === "left" || side === "up" };
}

// A window out of the tree: its sibling takes the whole of their split.
function remove(node, id) {
    if (!node)
        return null;
    if (isLeaf(node))
        return node.id === id ? null : node;
    const a = remove(node.a, id);
    const b = remove(node.b, id);
    if (!a)
        return b;
    if (!b)
        return a;
    return { dir: node.dir, ratio: node.ratio, a: a, b: b };
}

// Two windows trading places; the splits stay as they are.
function swap(node, one, other) {
    if (!node)
        return node;
    if (isLeaf(node)) {
        if (node.id === one)
            return leaf(other);
        return node.id === other ? leaf(one) : node;
    }
    return { dir: node.dir, ratio: node.ratio, a: swap(node.a, one, other), b: swap(node.b, one, other) };
}

function centre(r) {
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
}

// How far a point is in each direction, and how far off to the side.
const AXES = {
    left:  { along: c => -c.x, across: c => c.y, low: r => -r.x, high: r => -(r.x + r.width) },
    right: { along: c => c.x,  across: c => c.y, low: r => r.x + r.width, high: r => r.x },
    up:    { along: c => -c.y, across: c => c.x, low: r => -r.y, high: r => -(r.y + r.height) },
    down:  { along: c => c.y,  across: c => c.x, low: r => r.y + r.height, high: r => r.y }
};

// The window next to `id` in a direction: of those wholly past its edge
// that way, the nearest -- a step to the side counting double, so Right from
// the top of a stack goes to the top of the column beside it. Null when there
// is none, or `id` is not in the tree. `aspect` makes the distances pixels.
function neighbour(node, id, direction, aspect) {
    const axis = AXES[direction];
    const all = places(node);
    const from = all.find(p => p.id === id);
    if (!axis || !from)
        return null;
    const scale = r => rect(r.x * (aspect || 1), r.y, r.width * (aspect || 1), r.height);
    const here = scale(from.rect);
    const c = centre(here);
    let best = null;
    let bestScore = Infinity;
    for (const p of all) {
        const r = scale(p.rect);
        if (p.id === id || axis.high(r) < axis.low(here) - 1e-9)
            continue;
        const there = centre(r);
        const score = axis.along(there) - axis.along(c) + 2 * Math.abs(axis.across(there) - axis.across(c));
        if (score < bestScore) {
            best = p.id;
            bestScore = score;
        }
    }
    return best;
}

// A window moved one step: out of its place and in past its neighbour that
// way, splitting the neighbour's place -- Hyprland's movewindow. The tree as
// it was when there is no neighbour that way.
function move(node, id, direction, shape) {
    const s = shapeOf(shape);
    const next = neighbour(node, id, direction, s.aspect);
    if (next === null)
        return node;
    const moved = insert(remove(node, id), id, next, s, direction);
    return contains(moved, id) ? moved : node;
}

// ---- master and stack ------------------------------------------------------
//
// The other of Hyprland's layouts: the first window, the master, on the left
// at `ratio` of the width, and every other one in a column beside it, one
// above another in equal shares. The tree is made again from the order of
// the windows at every change, keeping the master's share as a resize left
// it; a split of the column into k is the same tree dwindle's are, so the
// tiles, the keys and `adopt` all work on it unchanged.

function column(list) {
    if (list.length === 1)
        return leaf(list[0]);
    return { dir: "v", ratio: 1 / list.length, a: leaf(list[0]), b: column(list.slice(1)) };
}

function master(list, ratio) {
    if (list.length === 0)
        return null;
    if (list.length === 1)
        return leaf(list[0]);
    return { dir: "h", ratio: ratio, a: leaf(list[0]), b: column(list.slice(1)) };
}

// The master's share as the tree has it now, or `fallback`.
function masterRatio(node, fallback) {
    return node && !isLeaf(node) && node.dir === "h" ? node.ratio : fallback;
}

// A window into a master layout: at the bottom of the column. The tree as it
// was when the column has no room for another window of KWin's smallest.
function insertMaster(node, id, shape) {
    if (contains(node, id))
        return node;
    const s = shapeOf(shape);
    const list = ids(node).concat([id]);
    const stack = list.length - 1;
    const ratio = masterRatio(node, s.ratio);
    if (stack > 0 && (1 / stack < s.min.height - 1e-9 || Math.min(ratio, 1 - ratio) < s.min.width - 1e-9))
        return node;
    return master(list, ratio);
}

function removeMaster(node, id, fallback) {
    if (!contains(node, id))
        return node;
    return master(ids(node).filter(other => other !== id), masterRatio(node, fallback));
}

function bounds(rects) {
    if (rects.length === 0)
        return null;
    const x = Math.min(...rects.map(r => r.x));
    const y = Math.min(...rects.map(r => r.y));
    const right = Math.max(...rects.map(r => r.x + r.width));
    const bottom = Math.max(...rects.map(r => r.y + r.height));
    return rect(x, y, right - x, bottom - y);
}

function clamp(ratio) {
    return Math.min(1 - MIN_RATIO, Math.max(MIN_RATIO, ratio));
}

// The splits made to agree with where the windows are now: after a resize,
// KWin has moved the edge two tiles share, and the tree takes that edge's
// new place as its ratio. `rectOf(id)` is a window's place in fractions of
// the screen, or null when it has none -- and a split with a window of no
// place on either side keeps the ratio it had.
function adopt(node, rectOf) {
    if (!node || isLeaf(node))
        return node;
    const a = adopt(node.a, rectOf);
    const b = adopt(node.b, rectOf);
    const ra = ids(node.a).map(rectOf);
    const rb = ids(node.b).map(rectOf);
    let ratio = node.ratio;
    if (ra.every(r => !!r) && rb.every(r => !!r)) {
        const ba = bounds(ra);
        const all = bounds(ra.concat(rb));
        const share = node.dir === "h" ? ba.width / all.width : ba.height / all.height;
        if (isFinite(share) && share > 0)
            ratio = clamp(share);
    }
    return { dir: node.dir, ratio: ratio, a: a, b: b };
}

// The tree as a snap layout -- { dir, parts }, each part a share of its box,
// a number for a window and a node for a box split again -- which is what
// layouts.js builds KWin's tiles from. A split inside a split the same way
// is folded into it: KWin's tiles have no such thing, since splitting a tile
// the way its parent is split adds a sibling to the parent instead. Null for
// a tree of one window or none, which is no layout.
function layout(node) {
    if (!node || isLeaf(node))
        return null;
    return { dir: node.dir, parts: flatten(node, node.dir, 1) };
}

function flatten(node, dir, share) {
    if (isLeaf(node))
        return [share];
    if (node.dir !== dir)
        return [{ size: share, dir: node.dir, parts: flatten(node, node.dir, 1) }];
    return flatten(node.a, dir, share * node.ratio).concat(flatten(node.b, dir, share * (1 - node.ratio)));
}
