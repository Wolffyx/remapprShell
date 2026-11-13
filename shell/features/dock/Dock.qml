pragma ComponentBehavior: Bound

// The dock: applications as large tiles floating clear of the screen's edge,
// as on macOS -- a second panel, beside the one every screen has.
//
// Off until `dock.enabled` (the macOS-like layout turns it on). What it holds
// is DockItems': the start button, the pinned applications and then the rest
// that are running, each with a dot under it while it has windows, and past a
// divider Downloads and the Trash. The tiles do what the taskbar's buttons do,
// through the same WindowsService: a click starts an application or raises
// it, on its active window minimises it, on one with several windows moves
// through them; a middle click starts another; a right click opens a menu to
// keep it in the dock or take it out, start another, or close its windows.
//
// One per screen, like the panel; `dock.enabled` can be set per monitor. The
// window is a strip along its edge with room above the tiles for the menu and
// the name of the tile under the pointer; only the dock itself -- the menu,
// while it is open, and on a dock that hides the edge below it -- takes the
// pointer, so the rest of the strip lets clicks through. `dock.visibility` decides whether windows stop above it,
// whether it hides until the pointer reaches the edge, or whether it hides
// while a window reaches into its space (DockItems.hidden). On the same edge
// as the panel, KWin puts it above the panel: both reserve their space.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.config
import qs.domain.desktops
import qs.domain.dock
import qs.domain.launcher
import qs.domain.theme
import qs.domain.windows
import qs.domain.windows.events
import qs.platform.system

PanelWindow {
    id: root

    required property var modelData
    screen: root.modelData

    readonly property string screenName: root.modelData.name

    function setting(path, fallback) {
        return ConfigStore.valueFor(root.screenName, path, fallback);
    }

    // ---- settings -----------------------------------------------------------

    readonly property string position: ["bottom", "left", "right"].indexOf(root.setting("dock.position", "bottom")) >= 0
        ? root.setting("dock.position", "bottom") : "bottom"
    readonly property bool horizontal: root.position === "bottom"
    readonly property int size: Math.max(32, Math.min(80, Number(root.setting("dock.iconSize", 48)) || 48))
    readonly property string visibility: root.setting("dock.visibility", "always")
    readonly property bool magnify: root.setting("dock.magnify", false) === true
    readonly property bool rearrange: root.setting("dock.rearrange", true) !== false
    readonly property bool dragToRemove: root.setting("dock.dragToRemove", true) !== false
    // How many times its size the tile under the pointer grows to.
    readonly property real peak: Math.max(1, Math.min(128, Number(root.setting("dock.magnifiedSize", 96)) || 96) / root.size)

    // What is pinned, or -- with nothing pinned yet -- the start menu's own
    // pins, so a first dock is not empty.
    readonly property var configuredPins: root.setting("dock.pinned", []) ?? []
    readonly property var pinned: root.configuredPins.length > 0
        ? root.configuredPins
        : (LauncherService.builtin.pinnedApps ?? []).slice(0, 8).map(a => String(a.id))

    readonly property var windowsHere: WindowsService.windows.filter(w => {
        const on = w?.desktops ?? [];
        return on.length === 0 || on.indexOf(Desktops.currentId) >= 0;
    })

    readonly property var items: DockItems.items(
        WindowEvents.arrangeTasks(WindowsService.groupsOf(root.windowsHere), root.pinned,
                                  id => WindowsService.launcherFor(id)),
        { launcher: root.setting("dock.launcher", true) !== false,
          running: root.setting("dock.running", true) !== false,
          pinned: root.pinned,
          places: root.setting("dock.places", true) !== false,
          downloads: Paths.downloads })

    // ---- size ----------------------------------------------------------------

    readonly property int pad: Math.round(root.size * 0.19)
    readonly property int gap: Math.round(root.size * 0.125)
    readonly property int margin: 8
    readonly property int thickness: root.size + 2 * root.pad
    // Over the tiles: the name, or the menu with an application's actions in
    // it (at most six of them, DockMenu.maxActions).
    readonly property int room: 400
    readonly property int dividerLength: 9

    // ---- magnifying ------------------------------------------------------------
    //
    // While the pointer is on the dock (and no menu is open) the tile under it
    // grows to `peak` times its size and the ones near it less (DockItems.
    // magnify). Where the pointer is gets measured along the dock as it would
    // be at rest, so growing tiles never move what it is measured against,
    // and the dock is then drawn with that point under the pointer
    // (DockItems.stretched): the tile the pointer is on stays under it, and
    // the dock spreads to both sides of it. The tiles grow out of the glass,
    // away from the edge, by up to `lift`, and that room takes the pointer
    // too while they do.

    readonly property var restLengths: root.items.map(i => i.kind === "divider" ? root.dividerLength : root.size)
    readonly property real restLength: root.restLengths.reduce((sum, len) => sum + len, 0)
        + root.gap * Math.max(0, root.restLengths.length - 1)
    readonly property var restCentres: DockItems.restCentres(root.restLengths, root.gap)
    readonly property real centreAlong: root.horizontal ? root.width / 2 : root.height / 2
    // Where the first tile starts at rest, along the window.
    readonly property real restStart: root.centreAlong - root.restLength / 2
    // How far either side of the pointer tiles still grow: two and a half.
    readonly property real reachLength: 2.5 * (root.size + root.gap)

    readonly property bool magnifying: root.magnify && root.peak > 1 && body.pointerOn
        && root.menuItem === null && !root.hidden && !body.dragging
    readonly property int lift: root.magnifying ? Math.ceil((root.peak - 1) * root.size) : 0
    readonly property real pointerAlong: root.horizontal ? body.pointer.x : body.pointer.y

    // The last place the pointer was on the dock, along the window and at
    // rest -- kept while the tiles settle back after it leaves.
    property real lastAlong: 0
    property real lastRest: 0
    function track() {
        if (!root.magnifying || !Number.isFinite(root.pointerAlong))
            return;
        root.lastAlong = root.pointerAlong;
        root.lastRest = root.pointerAlong - root.restStart;
    }
    onPointerAlongChanged: root.track()
    onMagnifyingChanged: root.track()

    // 0 to 1: how far the tiles have grown, so they grow and settle smoothly.
    property real level: root.magnifying ? 1 : 0
    Behavior on level { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }

    readonly property var scales: DockItems.magnify(root.restCentres, root.lastRest,
                                                    1 + (root.peak - 1) * root.level, root.reachLength)
    // Where the first tile starts, along the window.
    readonly property real tilesStart: root.level > 0
        ? root.lastAlong - DockItems.stretched(root.restLengths, root.scales, root.gap, root.lastRest)
        : root.restStart

    // ---- showing and hiding ----------------------------------------------------

    // Whether the pointer is on anything of the dock's: the glass, the strip
    // along the edge, the open menu. Read off their own HoverHandlers rather
    // than kept from their events: going from the strip to the glass, the
    // strip's "left" can come after the glass's "entered", and a flag set by
    // the last event to arrive then says the pointer is off the dock while
    // it is on it -- and the dock hid under it.
    readonly property bool pointerInside: body.pointerOn || stripHover.hovered || menu.pointerOn
    property var menuItem: null

    readonly property bool windowNear: root.visibility === "dodge"
        && WindowEvents.reachesEdge(WindowsService.windows, Desktops.currentId,
                                    { name: root.screenName, x: root.modelData.x, y: root.modelData.y,
                                      width: root.modelData.width, height: root.modelData.height },
                                    root.position, root.thickness + root.margin)

    readonly property bool hidden: DockItems.hidden(root.visibility, {
        pointerInside: root.pointerInside || leaveDelay.running || body.dragging,
        menuOpen: root.menuItem !== null,
        windowNear: root.windowNear
    })

    // How far the dock has slid out of sight, 0 to 1.
    property real away: root.hidden ? 1 : 0
    Behavior on away { NumberAnimation { duration: Theme.durationMedium; easing.type: Easing.OutCubic } }

    // Leaving starts a short countdown, so crossing the gap between the dock
    // and its menu does not put it away; coming back calls it off.
    Timer {
        id: leaveDelay
        interval: 500
        onTriggered: {
            if (!root.pointerInside)
                root.menuItem = null;
        }
    }

    onPointerInsideChanged: {
        if (root.pointerInside)
            leaveDelay.stop();
        else
            leaveDelay.restart();
    }

    // ---- the window ------------------------------------------------------------

    anchors {
        bottom: root.position === "bottom"
        left: root.position !== "right"
        right: root.position !== "left"
        top: root.position !== "bottom"
    }
    implicitHeight: root.horizontal ? root.margin + root.thickness + root.room : 0
    implicitWidth: root.horizontal ? 0 : root.margin + root.thickness + root.room

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.visibility === "always" ? root.thickness + 2 * root.margin : 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: Layers.chrome
    color: "transparent"

    // Only the dock takes the pointer -- and, on a dock that hides, the strip
    // along the edge (DockItems.edgeDepth), and the menu while it is open.
    readonly property int edgeDepth: DockItems.edgeDepth(root.visibility, root.hidden, root.margin)
    mask: Region {
        regions: [root._bodyRegion].concat(root.edgeDepth > 0 ? [root._stripRegion] : [])
                                   .concat(root.menuItem !== null ? [root._menuRegion] : [])
    }
    readonly property Region _bodyRegion: Region { item: zone }
    readonly property Region _stripRegion: Region { item: strip }
    readonly property Region _menuRegion: Region { item: menu }

    // Where the dock sits: centred along its edge (or spread round the
    // pointer while it magnifies), `margin` in from the edge, and slid past
    // it by `away`.
    readonly property real slide: root.away * (root.thickness + root.margin + 2)
    readonly property real bodyStart: root.tilesStart - root.pad
    readonly property var _placeBody: ({
        bottom: () => Qt.point(root.bodyStart, root.height - root.margin - root.thickness + root.slide),
        left: () => Qt.point(root.margin - root.slide, root.bodyStart),
        right: () => Qt.point(root.width - root.margin - root.thickness + root.slide, root.bodyStart)
    })
    readonly property point bodyAt: root._placeBody[root.position]()

    // What takes the pointer for the dock: the glass, and the room the tiles
    // grow into while they do.
    Item {
        id: zone
        x: root.position === "right" ? body.x - root.lift : body.x
        y: root.horizontal ? body.y - root.lift : body.y
        width: body.width + (root.horizontal ? 0 : root.lift)
        height: body.height + (root.horizontal ? root.lift : 0)
    }

    // The edge the hidden dock comes back from -- and, while it is shown,
    // the gap between the edge and the glass, so the pointer can rest at
    // the edge.
    Item {
        id: strip
        readonly property int depth: Math.max(1, root.edgeDepth)
        x: root.position === "right" ? root.width - strip.depth : 0
        y: root.horizontal ? root.height - strip.depth : 0
        width: root.horizontal ? root.width : strip.depth
        height: root.horizontal ? strip.depth : root.height
        HoverHandler { id: stripHover }
    }

    DockBody {
        id: body
        dock: root
        x: root.bodyAt.x
        y: root.bodyAt.y
        opacity: 1 - root.away * 0.6
    }

    DockMenu {
        id: menu
        dock: root
        body: body
    }

    // ---- what the tiles do ---------------------------------------------------

    readonly property var _kinds: ({
        launcher: (item, button) => root.toggleLauncher(),
        divider: (item, button) => {},
        place: (item, button) => Launch.open(item.uri),
        app: (item, button) => root.activateApp(item, button)
    })

    function activate(item, button) {
        if (!item)
            return;
        if (button === Qt.RightButton) {
            root.menuItem = item.kind === "app" ? item : null;
            return;
        }
        root.menuItem = null;
        (root._kinds[item.kind] ?? root._kinds.divider)(item, button);
    }

    // The start menu -- or Launchpad -- on this screen, as the panel's start
    // button does: another provider (Kickoff, KRunner) is asked to toggle.
    function toggleLauncher() {
        const builtin = LauncherService.builtin;
        if (LauncherService.active !== builtin) {
            LauncherService.toggle("apps");
            return;
        }
        if (builtin.visible && builtin.mode === "apps" && builtin.shownOn === root.screenName)
            builtin.close();
        else
            builtin.openOn(root.screenName, "apps");
    }

    // What the taskbar's buttons do (see the tasks widget).
    function activateApp(item, button) {
        if (button === Qt.MiddleButton || item.windows.length === 0) {
            WindowsService.launch(WindowEvents.appIdOf(item), null);
            return;
        }
        if (item.windows.length === 1 && item.windows[0].active) {
            WindowsService.minimizeActive();
            return;
        }
        WindowsService.activateGroup(item);
    }

    // The application's desktop entry, for its own actions; null for a
    // window no installed application matched.
    function entryOf(item) {
        if (item?.kind !== "app")
            return null;
        return WindowsService.entryById(WindowEvents.appIdOf(item));
    }

    // One of those actions -- "New private window" -- started as the
    // taskbar's menu starts it.
    function launchAction(item, action) {
        WindowsService.launch(WindowEvents.appIdOf(item), action);
        root.menuItem = null;
    }

    function isPinned(item) {
        return root.pinned.indexOf(String(item?.appKey ?? "")) >= 0;
    }

    // Keeping one in the dock writes the list out, the start menu's pins
    // included when those were what it showed: from now on it is the dock's.
    function togglePin(item) {
        ConfigStore.set("dock.pinned", DockItems.togglePin(root.pinned, item?.appKey));
        root.menuItem = null;
    }

    // A tile dragged from `from` to `to` (DockBody): the new order is written
    // the way keeping one is, start menu pins included when those were what
    // the dock showed.
    function moveTile(from, to) {
        const next = DockItems.reorder(root.items, root.pinned, from, to);
        if (next !== null)
            ConfigStore.set("dock.pinned", next);
    }

    // A kept tile carried off the dock (DockBody) is taken out of it, as
    // "Remove from the dock" does; a running application stays, as one not
    // kept.
    function removeTile(item) {
        const next = DockItems.unpin(root.pinned, item?.appKey);
        if (next !== null)
            ConfigStore.set("dock.pinned", next);
    }

    function closeWindows(item) {
        for (const w of item?.windows ?? [])
            WindowsService.close(w.uuid);
        root.menuItem = null;
    }
}
