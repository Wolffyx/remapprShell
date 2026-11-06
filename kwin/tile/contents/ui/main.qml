/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Automatic tiling, as Hyprland's dwindle layout has it: every window that
    opens takes half of the focused one, split along its longer side, and a
    window that closes gives its half back -- on each screen and each virtual
    desktop separately. Keys move the focus, move a window, or swap two, in a
    direction; one floats the active window and another turns tiling off and
    on for the desktop in front.

    The tree is this script's (dwindle.js); the tiles are KWin's. Each change
    makes the screen's tiles that tree -- through layouts.js, the snap
    layouts' own, which is the same file -- and gives every window its tile,
    so the gap is KWin's tile padding, resizing a window moves the edge it
    shares with its neighbours (and the tree takes the new edge), and a
    window let go of gets back the size it had. Where KWin has no tiles, each
    window is moved and sized instead.

    Floating, always: anything that is not a normal window, a dialog, a
    transient or modal window, one that cannot be resized or has one size
    only, a full-screen one, a minimised one, one on every desktop, and
    KWin's own windows.

    A declarative script for the same reason the snap layouts are one: the
    tile and shortcut types are there and nowhere else. It draws nothing.
*/

// KWin's types live in its own process and cannot be resolved by the linter.
// qmllint disable unqualified
import QtQuick
import org.kde.kwin
import "dwindle.js" as Dwindle
import "layouts.js" as Layouts

Item {
    id: root

    // The gap around a tiled window, which `rmpr windows behaviour set
    // tileGap` writes here as well as for the snap layouts: one setting,
    // given to every root tile this script uses -- a desktop or screen added
    // later comes with KWin's own 4. -1, unset, leaves KWin's padding alone.
    readonly property int gap: Number(KWin.readConfig("Gap", -1))

    // Settings > Tiling, through `rmpr windows behaviour`, in this script's
    // group. The layout: "dwindle", or "master" -- one window on the left and
    // the rest in a column beside it. The most windows tiled on a screen and
    // desktop, 0 for as many as KWin's smallest tile allows; a window past
    // either floats until one of the tiled ones goes. And a share, in
    // percent: a new window's of the split it makes (dwindle), or the
    // master's of the width.
    readonly property string layoutName: String(KWin.readConfig("Layout", "dwindle")) === "master" ? "master" : "dwindle"
    readonly property int maxTiled: Math.max(0, Number(KWin.readConfig("Max", 0)) || 0)
    readonly property real share: Math.min(0.8, Math.max(0.2, (Number(KWin.readConfig("Ratio", 50)) || 50) / 100))

    // KWin's Tile.LayoutDirection, as the scripting API numbers it.
    readonly property var directions: ({ h: 1, v: 2 })

    // The actions this script registers, for this project's keys to reach it
    // by: the key is held by the session daemon, as every key of ours is, and
    // pressing it runs `windows tile <verb> [direction]`, which invokes the
    // action through kglobalaccel. The same names are in
    // scripts/lib/windows/tile.sh, and test-windows.sh checks they agree.
    readonly property var actions: [
        { name: "Auto Tile: Focus Left",  text: "Auto-tiling: focus the window to the left",  run: () => root.focusTowards("left") },
        { name: "Auto Tile: Focus Right", text: "Auto-tiling: focus the window to the right", run: () => root.focusTowards("right") },
        { name: "Auto Tile: Focus Up",    text: "Auto-tiling: focus the window above",        run: () => root.focusTowards("up") },
        { name: "Auto Tile: Focus Down",  text: "Auto-tiling: focus the window below",        run: () => root.focusTowards("down") },
        { name: "Auto Tile: Move Left",   text: "Auto-tiling: move the window left",          run: () => root.rearrange("move", "left") },
        { name: "Auto Tile: Move Right",  text: "Auto-tiling: move the window right",         run: () => root.rearrange("move", "right") },
        { name: "Auto Tile: Move Up",     text: "Auto-tiling: move the window up",            run: () => root.rearrange("move", "up") },
        { name: "Auto Tile: Move Down",   text: "Auto-tiling: move the window down",          run: () => root.rearrange("move", "down") },
        { name: "Auto Tile: Swap Left",   text: "Auto-tiling: swap with the window to the left",  run: () => root.rearrange("swap", "left") },
        { name: "Auto Tile: Swap Right",  text: "Auto-tiling: swap with the window to the right", run: () => root.rearrange("swap", "right") },
        { name: "Auto Tile: Swap Up",     text: "Auto-tiling: swap with the window above",        run: () => root.rearrange("swap", "up") },
        { name: "Auto Tile: Swap Down",   text: "Auto-tiling: swap with the window below",        run: () => root.rearrange("swap", "down") },
        { name: "Auto Tile: Toggle Floating", text: "Auto-tiling: float the active window, or tile it again", run: () => root.toggleFloating() },
        { name: "Auto Tile: Toggle Desktop",  text: "Auto-tiling: off or on for the current desktop",        run: () => root.toggleDesktop() }
    ]

    // Per screen and desktop, by `keyOf`: { output, desktop, tree, focus },
    // the tree of tiled windows and the one last focused there.
    property var trees: ({})
    // Each tiled window's key, by its id: where it is tiled.
    property var placed: ({})
    // The windows floated by the key, and the desktops tiling is off on, by
    // id. Neither outlives the script: a reload tiles everything again.
    property var floating: ({})
    property var off: ({})
    // The keys whose tiles are to be made again, once this turn is over:
    // opening a dozen windows at a load is one rebuild a screen, not twelve.
    property var dirty: ({})
    // The windows by id, for the trees, which hold ids.
    property var known: ({})
    // What each window was doing when a move or resize began, by id.
    property var gesture: ({})
    // The windows that would be tiled but found no room, by id: the key of
    // the tree they wait for. Tried again when a window leaves that tree.
    property var overflow: ({})

    function idOf(w) {
        return String(w.internalId);
    }

    function windows() {
        return typeof Workspace.windowList === "function" ? Workspace.windowList() : Workspace.stackingOrder;
    }

    // KWin's own windows belong to no process and no application; see
    // kwin/windows for the same test.
    function isKWinsOwn(w) {
        return w.pid === -1 && !w.resourceClass;
    }

    // One size only: a minimum and a maximum that agree.
    function fixedSize(w) {
        const lo = w.minSize, hi = w.maxSize;
        return !!lo && !!hi && hi.width > 0 && hi.height > 0 && lo.width === hi.width && lo.height === hi.height;
    }

    // A window this script tiles: one a person opened to work in, which can
    // take any size. Each test is a reason a window stays floating.
    function tileable(w) {
        return !!w && w.normalWindow === true && !root.isKWinsOwn(w)
            && w.dialog !== true && w.transient !== true && w.modal !== true
            && w.resizeable === true && !root.fixedSize(w)
            && w.fullScreen !== true && w.minimized !== true
            && w.specialWindow !== true && w.popupWindow !== true
            && w.deleted !== true && !root.floating[root.idOf(w)]
            && !!w.output && !!w.desktops && w.desktops.length === 1
            && !root.off[String(w.desktops[0].id)];
    }

    function keyOf(output, desktop) {
        return `${output.name}\n${desktop.id}`;
    }

    function treeFor(output, desktop) {
        const key = root.keyOf(output, desktop);
        if (!root.trees[key])
            root.trees[key] = { output: output, desktop: desktop, tree: null, focus: "" };
        return root.trees[key];
    }

    function rootTile(output, desktop) {
        if (typeof Workspace.rootTile === "function")
            return Workspace.rootTile(output, desktop);
        if (typeof Workspace.tilingForScreen !== "function")
            return null;
        const manager = Workspace.tilingForScreen(output);
        return manager ? manager.rootTile : null;
    }

    function areaOf(entry) {
        return Workspace.clientArea(KWin.MaximizeArea, entry.output, entry.desktop);
    }

    function aspectOf(entry) {
        const a = root.areaOf(entry);
        return a.width / Math.max(1, a.height);
    }

    // How a split is made in this tree: dwindle.js's shapeOf. KWin's
    // smallest tile from KWin, where it says (6.8: 0.15 a side); none where
    // the windows are sized by hand.
    function shapeOf(entry) {
        const top = root.rootTile(entry.output, entry.desktop);
        const m = top && top.minimumSize;
        return {
            aspect: root.aspectOf(entry),
            min: m ? { width: m.width, height: m.height } : { width: 0, height: 0 },
            ratio: root.layoutName === "master" ? root.share : 1 - root.share
        };
    }

    // The tree with one more window, or as it was when there is no room.
    function grown(entry, id, target) {
        if (root.maxTiled > 0 && Dwindle.ids(entry.tree).length >= root.maxTiled)
            return entry.tree;
        const shape = root.shapeOf(entry);
        if (root.layoutName === "master")
            return Dwindle.insertMaster(entry.tree, id, shape);
        return Dwindle.insert(entry.tree, id, target, shape);
    }

    function shrunk(entry, id) {
        if (root.layoutName === "master")
            return Dwindle.removeMaster(entry.tree, id, root.share);
        return Dwindle.remove(entry.tree, id);
    }

    // The windows waiting for room in a tree, given another go.
    function retry(key) {
        const waiting = Object.keys(root.overflow).filter(id => root.overflow[id] === key);
        for (const id of waiting) {
            delete root.overflow[id];
            const w = root.known[id];
            if (w && w.deleted !== true)
                root.consider(w);
        }
    }

    // ---- keeping the trees -------------------------------------------------

    // A window's place made to agree with what it is now: tiled where it
    // should be, out of a tree it no longer belongs in. `near`, a window of
    // the same tree, is the one it splits when it comes in; the tree's
    // focused window otherwise.
    function consider(w, near) {
        const id = root.idOf(w);
        const want = root.tileable(w) ? root.keyOf(w.output, w.desktops[0]) : "";
        const have = root.placed[id] || "";
        if (want === have)
            return;
        delete root.overflow[id];
        if (have !== "")
            root.takeOut(id, have);
        if (want === "")
            return;
        const entry = root.treeFor(w.output, w.desktops[0]);
        const target = near && Dwindle.contains(entry.tree, near) ? near : entry.focus;
        const tree = root.grown(entry, id, target);
        if (!Dwindle.contains(tree, id)) {
            // No room: it floats where it opened, until a tiled one goes.
            root.overflow[id] = want;
            return;
        }
        entry.tree = tree;
        root.placed[id] = want;
        root.known[id] = w;
        root.touch(want);
    }

    function takeOut(id, key) {
        const entry = root.trees[key];
        delete root.placed[id];
        if (!entry)
            return;
        entry.tree = root.shrunk(entry, id);
        if (entry.focus === id)
            entry.focus = "";
        const w = root.known[id];
        if (w && w.deleted !== true)
            root.letGo(w, entry);
        root.touch(key);
        root.retry(key);
    }

    // The tile a window is in, in one tree's tiles. Not `window.tile` alone:
    // KWin 6.8 gives that for the desktop in front only, so a window tiled on
    // another desktop has none there (measured in the rig, 2026-10-18).
    function tileOf(w, entry) {
        if (w.tile)
            return w.tile;
        const top = root.rootTile(entry.output, entry.desktop);
        if (!top)
            return null;
        return Layouts.leaves(top).find(t => Layouts.windowsIn(t, root.windows()).indexOf(w) >= 0) || null;
    }

    // Out of its tile and left where it is, as the snap layouts let go of a
    // window: KWin would otherwise hand it to the tile above.
    function letGo(w, entry) {
        const tile = root.tileOf(w, entry);
        if (!tile)
            return;
        const g = w.frameGeometry;
        const kept = Qt.rect(g.x, g.y, g.width, g.height);
        Layouts.unmanage(tile, w);
        if (w.fullScreen !== true)
            w.frameGeometry = kept;
    }

    function touch(key) {
        root.dirty[key] = true;
        Qt.callLater(root.flush);
    }

    function flush() {
        const keys = Object.keys(root.dirty);
        root.dirty = {};
        keys.forEach(key => root.arrange(key));
    }

    // The tiles of one screen and desktop made the tree, and every window
    // given its tile.
    function arrange(key) {
        const entry = root.trees[key];
        if (!entry)
            return;
        const top = root.rootTile(entry.output, entry.desktop);
        const places = Dwindle.places(entry.tree);
        if (top && typeof top.split === "function") {
            root.arrangeTiles(top, entry.tree, places);
            return;
        }
        const area = root.areaOf(entry);
        const pad = Math.max(0, root.gap);
        for (const p of places) {
            const r = Layouts.place(p.rect, area);
            root.known[p.id].frameGeometry = Qt.rect(r.x + pad, r.y + pad, r.width - 2 * pad, r.height - 2 * pad);
        }
    }

    function arrangeTiles(top, tree, places) {
        if (root.gap >= 0 && top.padding !== root.gap)
            top.padding = root.gap;
        const shape = Dwindle.layout(tree);
        if (shape === null && Layouts.tileZones(top).length > 0) {
            // One window or none: the screen is one tile again.
            Layouts.release(top);
            for (const kid of Layouts.childrenOf(top).reverse())
                kid.remove();
        }
        if (shape !== null && !Layouts.build(top, shape, root.directions))
            console.warn("auto-tiling: KWin did not split its tiles as asked");
        for (const p of places) {
            const w = root.known[p.id];
            const tile = shape === null ? top : Layouts.leafFor(top, p.rect);
            if (tile && w.tile !== tile)
                Layouts.manage(tile, w);
        }
    }

    // ---- what the windows do -----------------------------------------------

    // What this script has connected to each window's signals, as
    // [window, signal, handler]: let go of when the script is unloaded, or a
    // handler outlives it (see kwin/snap).
    property var hooks: []

    function hook(w, signal, handler) {
        if (!signal)
            return;
        signal.connect(handler);
        root.hooks.push([w, signal, handler]);
    }

    function unhook() {
        for (const h of root.hooks)
            h[1].disconnect(h[2]);
        root.hooks = [];
    }

    function watch(w) {
        if (!w || w.normalWindow !== true || root.isKWinsOwn(w))
            return;
        const again = () => root.consider(w);
        root.hook(w, w.minimizedChanged, again);
        root.hook(w, w.fullScreenChanged, again);
        root.hook(w, w.outputChanged, again);
        root.hook(w, w.desktopsChanged, again);
        root.hook(w, w.interactiveMoveResizeStarted, () => root.begin(w));
        root.hook(w, w.interactiveMoveResizeFinished, () => root.finish(w));
        root.hook(w, w.closed, () => root.forget(w));
        root.consider(w);
    }

    // A window gone. It takes its connections with it, so they are only
    // forgotten, not disconnected from inside its own `closed`.
    function forget(w) {
        const id = root.idOf(w);
        if (root.placed[id])
            root.takeOut(id, root.placed[id]);
        delete root.known[id];
        delete root.floating[id];
        delete root.gesture[id];
        delete root.overflow[id];
        root.hooks = root.hooks.filter(h => h[0] !== w);
    }

    function begin(w) {
        root.gesture[root.idOf(w)] = { resize: w.resize === true, output: w.output };
    }

    // A resize moved an edge KWin's tiles share, and the tree takes it. A
    // move dropped the window: over another tiled window of the same screen,
    // the two swap; anywhere else it goes back to its tile -- or, on another
    // screen, into that screen's tree beside the window it was let go over.
    function finish(w) {
        const id = root.idOf(w);
        const was = root.gesture[id];
        delete root.gesture[id];
        const key = root.placed[id];
        if (!was || !key)
            return root.consider(w, root.windowAt(Workspace.cursorPos, w));
        const entry = root.trees[key];
        if (was.resize) {
            entry.tree = Dwindle.adopt(entry.tree, other => root.tileRect(root.known[other]));
            root.touch(key);
            return;
        }
        const under = root.windowAt(Workspace.cursorPos, w);
        if (under && Dwindle.contains(entry.tree, under))
            entry.tree = Dwindle.swap(entry.tree, id, under);
        root.touch(key);
    }

    // Where a window's tile is, in fractions of its screen, or null.
    function tileRect(w) {
        if (!w || !w.tile)
            return null;
        const g = w.tile.relativeGeometry;
        return { x: g.x, y: g.y, width: g.width, height: g.height };
    }

    // The tiled window under a point, other than `except`, by id; "" if none.
    function windowAt(point, except) {
        for (const id of Object.keys(root.placed)) {
            const w = root.known[id];
            if (!w || w === except)
                continue;
            const g = w.frameGeometry;
            if (Layouts.inside(g, point.x, point.y, 0) && w.desktops[0] === Workspace.currentDesktop)
                return id;
        }
        return "";
    }

    // ---- the keys -----------------------------------------------------------

    // The active window's tree, and the active window's id in it, or null.
    function activeEntry() {
        const w = Workspace.activeWindow;
        const key = w ? root.placed[root.idOf(w)] : "";
        return key ? { key: key, entry: root.trees[key], id: root.idOf(w) } : null;
    }

    function focusTowards(direction) {
        const at = root.activeEntry();
        if (!at)
            return;
        const next = Dwindle.neighbour(at.entry.tree, at.id, direction, root.aspectOf(at.entry));
        if (next !== null)
            Workspace.activeWindow = root.known[next];
    }

    // "move" or "swap" the active window one step in a direction.
    function rearrange(how, direction) {
        const at = root.activeEntry();
        if (!at)
            return;
        const aspect = root.aspectOf(at.entry);
        const before = at.entry.tree;
        // A master layout has its places fixed by the order: moving a
        // window there is trading places with the one next to it.
        if (how === "move" && root.layoutName !== "master") {
            at.entry.tree = Dwindle.move(before, at.id, direction, root.shapeOf(at.entry));
        } else {
            const next = Dwindle.neighbour(before, at.id, direction, aspect);
            if (next !== null)
                at.entry.tree = Dwindle.swap(before, at.id, next);
        }
        if (at.entry.tree !== before)
            root.touch(at.key);
    }

    function toggleFloating() {
        const w = Workspace.activeWindow;
        if (!w || w.normalWindow !== true || root.isKWinsOwn(w))
            return;
        const id = root.idOf(w);
        if (root.floating[id])
            delete root.floating[id];
        else
            root.floating[id] = true;
        root.consider(w);
    }

    function toggleDesktop() {
        const desktop = Workspace.currentDesktop;
        const id = String(desktop.id);
        if (root.off[id])
            delete root.off[id];
        else
            root.off[id] = true;
        root.windows().forEach(w => root.consider(w));
    }

    // ShortcutHandler is made at run time, so that a KWin without it loads
    // the rest of the script and only the keys do nothing (see kwin/snap).
    function listen() {
        for (const action of root.actions) {
            try {
                const handler = Qt.createQmlObject(`import org.kde.kwin; ShortcutHandler {
                    name: "${action.name}"; text: "${action.text}"; sequence: "" }`, root, "tileAction");
                handler.activated.connect(action.run);
            } catch (e) {
                console.warn(`auto-tiling: this KWin has no ShortcutHandler, so no key reaches it (${e})`);
                return;
            }
        }
    }

    function remember(w) {
        const key = w ? root.placed[root.idOf(w)] : "";
        if (key)
            root.trees[key].focus = root.idOf(w);
    }

    // Every tiled window let go of, where it is: turning auto-tiling off
    // leaves the windows as they are, floating.
    function releaseAll() {
        for (const id of Object.keys(root.placed)) {
            const w = root.known[id];
            if (w && w.deleted !== true)
                root.letGo(w, root.trees[root.placed[id]]);
        }
        root.placed = {};
    }

    Connections {
        target: Workspace

        function onWindowAdded(w) {
            root.known[root.idOf(w)] = w;
            root.watch(w);
        }

        function onWindowActivated(w) {
            root.remember(w);
        }

        function onScreensChanged() {
            root.windows().forEach(w => root.consider(w));
            Object.keys(root.trees).forEach(key => root.touch(key));
        }
    }

    Component.onCompleted: {
        root.listen();
        // In KWin's order, each window splitting the one before it, as if
        // they had been opened one after another with nothing else focused.
        for (const w of root.windows()) {
            root.known[root.idOf(w)] = w;
            root.watch(w);
            root.remember(w);
        }
        root.remember(Workspace.activeWindow);
    }

    Component.onDestruction: {
        root.unhook();
        root.releaseAll();
    }
}
