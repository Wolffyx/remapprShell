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
// the name of the tile under the pointer; only the dock itself -- and the
// menu, while it is open -- takes the pointer, so the rest of the strip lets
// clicks through. `dock.visibility` decides whether windows stop above it,
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
          downloads: `${Paths.home}/Downloads` })

    // ---- size ----------------------------------------------------------------

    readonly property int pad: Math.round(root.size * 0.19)
    readonly property int gap: Math.round(root.size * 0.125)
    readonly property int margin: 8
    readonly property int thickness: root.size + 2 * root.pad
    readonly property int room: 280

    // ---- showing and hiding ----------------------------------------------------

    property bool pointerInside: false
    property var menuItem: null

    readonly property bool windowNear: root.visibility === "dodge"
        && WindowEvents.reachesEdge(WindowsService.windows, Desktops.currentId,
                                    { name: root.screenName, x: root.modelData.x, y: root.modelData.y,
                                      width: root.modelData.width, height: root.modelData.height },
                                    root.position, root.thickness + root.margin)

    readonly property bool hidden: DockItems.hidden(root.visibility, {
        pointerInside: root.pointerInside || leaveDelay.running,
        menuOpen: root.menuItem !== null,
        windowNear: root.windowNear
    })

    // How far the dock has slid out of sight, 0 to 1.
    property real away: root.hidden ? 1 : 0
    Behavior on away { NumberAnimation { duration: Theme.durationMedium; easing.type: Easing.OutCubic } }

    // Leaving starts a short countdown, so crossing the gap between the dock
    // and its menu does not put it away.
    Timer {
        id: leaveDelay
        interval: 500
        onTriggered: {
            if (!root.pointerInside)
                root.menuItem = null;
        }
    }

    function pointerMoved(inside) {
        root.pointerInside = inside;
        if (!inside)
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

    // Only the dock takes the pointer -- and the strip at the edge while it
    // is hidden, and the menu while it is open.
    mask: Region {
        regions: [root._bodyRegion].concat(root.hidden ? [root._stripRegion] : [])
                                   .concat(root.menuItem !== null ? [root._menuRegion] : [])
    }
    readonly property Region _bodyRegion: Region { item: body }
    readonly property Region _stripRegion: Region { item: strip }
    readonly property Region _menuRegion: Region { item: menu }

    // Where the dock sits: centred along its edge, `margin` in from it, and
    // slid past the edge by `away`.
    readonly property real slide: root.away * (root.thickness + root.margin + 2)
    readonly property var _placeBody: ({
        bottom: () => Qt.point((root.width - body.width) / 2, root.height - root.margin - root.thickness + root.slide),
        left: () => Qt.point(root.margin - root.slide, (root.height - body.height) / 2),
        right: () => Qt.point(root.width - root.margin - root.thickness + root.slide, (root.height - body.height) / 2)
    })
    readonly property point bodyAt: root._placeBody[root.position]()

    // The edge the hidden dock comes back from.
    Item {
        id: strip
        x: root.position === "right" ? root.width - 3 : 0
        y: root.horizontal ? root.height - 3 : 0
        width: root.horizontal ? root.width : 3
        height: root.horizontal ? 3 : root.height
        HoverHandler { onHoveredChanged: root.pointerMoved(hovered) }
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

    function isPinned(item) {
        return root.pinned.indexOf(String(item?.appKey ?? "")) >= 0;
    }

    // Keeping one in the dock writes the list out, the start menu's pins
    // included when those were what it showed: from now on it is the dock's.
    function togglePin(item) {
        ConfigStore.set("dock.pinned", DockItems.togglePin(root.pinned, item?.appKey));
        root.menuItem = null;
    }

    function closeWindows(item) {
        for (const w of item?.windows ?? [])
            WindowsService.close(w.uuid);
        root.menuItem = null;
    }
}
