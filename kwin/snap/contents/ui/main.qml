/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Snap layouts, as Windows 11 has them: drag a window toward the top of a
    screen, a panel of layouts opens there, and letting go over one of its
    zones puts the window in that zone. Meta+Z opens the same panel for the
    active window, to choose a zone from with the pointer or the keys. And
    Snap Assist: once a window is snapped into a layout with zones still
    empty, the screen's other windows are offered to fill the first of them.

    KWin draws all of it and does the placing; only the choice of layouts is
    this project's. A zone is a KWin tile. Letting go over one makes the
    screen's tiles that layout -- the tiles Meta+T edits and Shift-dragging
    fills -- and gives the window its tile, so KWin does the rest the way it
    does for its own: dragging the window out again gives it back its size,
    the gap around it is KWin's tile padding, and the edge between two tiled
    windows moves both. A screen whose tiles are already some other layout,
    made in Meta+T, has that layout first in the panel. Where KWin has no
    tiles to give, the window is moved and sized to the zone instead.

    A declarative script because a JS one cannot draw, and a script rather
    than an effect for the reasons kwin/windows gives. It holds no qs.*
    imports: it runs inside kwin_wayland, not the shell.
*/

// KWin's types live in its own process and cannot be resolved by the linter.
// qmllint disable unqualified
import QtQuick
import org.kde.kwin
import QtQuick.Window as QuickWindow
import "layouts.js" as Layouts

Item {
    id: root

    // "top": a handle at the top of the screen while a window is dragged,
    // and the panel once the pointer comes near it, as Windows 11 does.
    // "drag": the panel as soon as a window is dragged. In kwinrc, in the
    // script's own group, where `rmpr windows behaviour` writes it.
    readonly property string reveal: String(KWin.readConfig("Reveal", "top"))
    // Snap Assist, unless `rmpr windows behaviour` has turned it off: on, as
    // Windows has it. In the same group.
    readonly property bool assistOn: String(KWin.readConfig("Assist", true)) === "true"
    // The gap around a tiled window, in pixels: KWin's tile padding, given
    // to every screen's tiles on every desktop. KWin keeps a padding per
    // screen and desktop, 4 px unless Meta+T changed it, and has no one
    // setting for them all. Unset (-1) leaves each as KWin has it. In the
    // same group.
    readonly property int gap: Number(KWin.readConfig("Gap", -1))

    // KWin's Tile.LayoutDirection, as the scripting API numbers it.
    readonly property var directions: ({ h: 1, v: 2 })

    // The panel's measures: the longer side of a card, the gaps between
    // cards, around them and around each zone.
    readonly property var metrics: ({ card: 96, gapX: 14, gapY: 12, pad: 8, inset: 2 })

    // How far below the top of the screen's free area the panel opens --
    // none: it hangs from the edge, as a drop-down does (10 px was "too far
    // from the edge", the user on 2026-10-17) -- and how close the pointer
    // must come to it: within `approach` of the top, over the panel's width
    // give or take `margin`, opens it; leaving it by more than `margin`
    // closes it again.
    readonly property int topGap: 0
    readonly property int approach: 72
    readonly property int margin: 48

    property var dragged: null         // the window being dragged, or null
    property var startGeometry: null   // where it was when the drag began
    property var output: null          // the screen the pointer is on
    property rect area                 // that screen's room for windows
    property var layouts: []           // [{ id, tree, zones }] for that screen
    property var arrangement: null     // the panel, from Layouts.arrange
    property int current: -1           // the layout the screen's tiles make now
    property bool revealed: false
    property var hover: null           // { layout, zone }, or null
    // Where the window would go, in the screen's pixels, or null.
    readonly property var target: root.hover
        ? Layouts.place(root.layouts[root.hover.layout].zones[root.hover.zone], root.area) : null

    function windows() {
        return typeof Workspace.windowList === "function" ? Workspace.windowList() : Workspace.stackingOrder;
    }

    // What a zone can be given: a window the user could have sized there
    // by hand. Not a dialog that cannot resize, not a panel, not a popup --
    // the chooser among them, which KWin lists as a normal window.
    function snappable(w) {
        return !!w && w.normalWindow === true && w.moveable === true && w.resizeable === true
            && w.fullScreen !== true && w.popupWindow !== true && w.specialWindow !== true
            && !root.isKWinsOwn(w);
    }

    // KWin's own windows -- this script's panel and chooser among them,
    // which KWin calls normal windows -- belong to no process and no
    // application, and are never dragged; see kwin/windows for the same test.
    function isKWinsOwn(w) {
        return w.pid === -1 && !w.resourceClass;
    }

    // What this script has connected to each window's signals, as
    // [window, signal, handler]: let go of when the script is unloaded.
    // KWin keeps the windows, and a handler left on one outlives the script
    // -- a reload left the old one's on every window, failing at each drag
    // on a `root` that was gone.
    property var hooks: []

    function hook(w, signal, handler) {
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
        root.hook(w, w.interactiveMoveResizeStarted, () => root.begin(w));
        root.hook(w, w.interactiveMoveResizeFinished, () => root.finish(w));
        root.hook(w, w.closed, () => root.forget(w));
    }

    // A window gone while it was dragged, being placed, or offered. It takes
    // its own connections with it, so its entries are only forgotten, not
    // disconnected from inside its own `closed` while KWin is taking it apart.
    function forget(w) {
        if (w === root.dragged)
            root.reset();
        picker.forget(w);
        root.hooks = root.hooks.filter(h => h[0] !== w);
    }

    // The tiles of a screen on the desktop in front. A KWin from before
    // tiles were kept per desktop has one set a screen.
    function rootTile(output) {
        if (typeof Workspace.rootTile === "function")
            return Workspace.rootTile(output, Workspace.currentDesktop);
        if (typeof Workspace.tilingForScreen !== "function")
            return null;
        const manager = Workspace.tilingForScreen(output);
        return manager ? manager.rootTile : null;
    }

    // Setting the root tile's padding sets its tiles' too, and the tiles a
    // split makes later take it from their parent.
    function applyGap() {
        if (!(root.gap >= 0) || typeof Workspace.rootTile !== "function")
            return;
        for (const output of Workspace.screens) {
            for (const desktop of Workspace.desktops) {
                const top = Workspace.rootTile(output, desktop);
                if (top && top.padding !== root.gap)
                    top.padding = root.gap;
            }
        }
    }

    function outputAt(point) {
        if (typeof Workspace.screenAt === "function")
            return Workspace.screenAt(point);
        return Workspace.activeScreen;
    }

    // The presets for this screen's shape, and the layout its tiles make
    // now when that is none of them -- one made in Meta+T, say -- first.
    // The one the tiles make now is marked: a window snapped into it joins
    // the windows already there, where any other layout lets them go.
    function layoutsFor(output, area) {
        const list = Layouts.presets(area.height > area.width);
        const top = root.rootTile(output);
        const current = top ? Layouts.tileZones(top) : [];
        if (current.length > 0 && !list.some(l => Layouts.sameZones(l.zones, current)))
            list.unshift({ id: "kwin", tree: null, zones: current });
        root.current = current.length > 0 ? list.findIndex(l => Layouts.sameZones(l.zones, current)) : -1;
        return list;
    }

    function settle(output) {
        root.output = output;
        root.area = Workspace.clientArea(KWin.MaximizeArea, output, Workspace.currentDesktop);
        root.layouts = root.layoutsFor(output, root.area);
        root.arrangement = Layouts.arrange(root.layouts, root.area.width / Math.max(1, root.area.height), root.metrics);
    }

    // ---- dragging ----------------------------------------------------------

    function begin(w) {
        if (w.move !== true || !root.snappable(w))
            return;
        if (picker.mode !== "")
            picker.close();
        const g = w.frameGeometry;
        root.startGeometry = Qt.rect(g.x, g.y, g.width, g.height);
        root.settle(root.outputAt(Workspace.cursorPos));
        root.revealed = root.reveal === "drag";
        root.hover = null;
        root.dragged = w;
        root.track();
    }

    // Near enough to open the panel, or to keep it open. Measured against
    // where the open panel is, or would be: the handle is far smaller than
    // the panel, and a pointer aimed at a card would otherwise close it.
    function near(point) {
        const width = root.arrangement.width + 2 * root.margin;
        const left = root.area.x + (root.area.width - width) / 2;
        if (!root.revealed)
            return point.y <= root.area.y + root.approach && point.x >= left && point.x < left + width;
        return Layouts.inside(Qt.rect(left, root.area.y, width, root.topGap + root.arrangement.height + 2 * root.margin),
                              point.x, point.y, 0);
    }

    // The zone under a point of the screen, on the panel `fly` draws in the
    // window `win`.
    function zoneAt(point, win, fly) {
        const x = point.x - win.x - fly.x - fly.cardLayer.x;
        const y = point.y - win.y - fly.y - fly.cardLayer.y;
        return Layouts.hit(root.arrangement, x, y, root.metrics.inset);
    }

    function track() {
        const point = Workspace.cursorPos;
        const output = root.outputAt(point);
        if (output && output !== root.output)
            root.settle(output);
        root.revealed = root.reveal === "drag" || root.near(point);
        const target = root.revealed ? root.zoneAt(point, panel, flyout) : null;
        if (!Layouts.sameHit(target, root.hover))
            root.hover = target;
    }

    function reset() {
        root.dragged = null;
        root.hover = null;
        root.revealed = false;
    }

    // Escape puts a dragged window back where it was and ends the drag like
    // any other; a window that has not moved was not dropped anywhere.
    function finish(w) {
        if (w !== root.dragged)
            return;
        const target = root.hover;
        const g = w.frameGeometry;
        const moved = g.x !== root.startGeometry.x || g.y !== root.startGeometry.y;
        const layout = target ? root.layouts[target.layout] : null;
        root.reset();
        if (!layout || !moved)
            return;
        root.snap(w, layout, layout.zones[target.zone]);
        picker.followUp(layout);
    }

    function snap(w, layout, zone) {
        const top = root.rootTile(root.output);
        const tiles = !!top && typeof top.split === "function";
        const shaped = tiles && (layout.tree === null || Layouts.build(top, layout.tree, root.directions));
        const tile = shaped ? Layouts.leafFor(top, zone) : null;
        if (tile) {
            Layouts.manage(tile, w);
            return;
        }
        const r = Layouts.place(zone, root.area);
        w.frameGeometry = Qt.rect(r.x, r.y, r.width, r.height);
    }

    Connections {
        target: Workspace
        enabled: root.dragged !== null

        function onCursorPosChanged() {
            root.track();
        }
    }

    Connections {
        target: Workspace

        function onWindowAdded(w) {
            root.watch(w);
        }

        // A screen plugged in or a desktop added comes with KWin's padding.
        function onScreensChanged() {
            root.applyGap();
        }

        function onDesktopsChanged() {
            root.applyGap();
        }
    }

    Component.onCompleted: {
        root.applyGap();
        root.windows().forEach(w => root.watch(w));
    }
    Component.onDestruction: root.unhook()

    // One window over the screen's free area for a drag, holding the preview
    // and the panel above it: a window each put the preview over the panel,
    // and KWin would not be asked to restack them. A plain window, as KWin's
    // own snapping outline is -- one KWin draws above everything at the place
    // it is given -- and named as that one names it, QuickWindow.Window,
    // since org.kde.kwin has a Window of its own that cannot be made. It
    // takes no keys, and needs none: KWin holds the pointer and the keyboard
    // for the whole drag.
    QuickWindow.Window {
        id: panel

        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        // Declared inside an Item, a window takes that item's window as its
        // transient parent and waits for it to be shown -- and the item this
        // script is has none, so it would wait for ever.
        transientParent: null
        color: "transparent"
        visible: root.dragged !== null

        x: root.area.x
        y: root.area.y
        width: Math.max(1, root.area.width)
        height: Math.max(1, root.area.height)

        Preview {
            area: root.area
            target: root.target
        }

        Flyout {
            id: flyout

            x: Math.round((panel.width - flyout.implicitWidth) / 2)
            y: root.topGap - flyout.shadowPad
            width: flyout.implicitWidth
            height: flyout.implicitHeight
            arrangement: root.arrangement
            hover: root.hover
            current: root.current
            revealed: root.revealed
        }
    }

    // Meta+Z and Snap Assist, in a window of their own that takes clicks and
    // keys.
    Picker {
        id: picker

        host: root
        assistOn: root.assistOn
    }
}
