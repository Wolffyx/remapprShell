pragma ComponentBehavior: Bound

// Composition root. It wires features together and owns no logic of its own --
// every behaviour lives in a layer below (see scripts/lint-layers.sh).
//
// What it wires is in three parts beside it: what is drawn on each screen
// (ShellScreens), the windows opened on request (ShellWindows), and what the
// shell answers over IPC (ShellIpc). What stays here is what must start with
// the shell, and the two routes in that are not IPC -- the pointer and the
// shell's own keys.

import QtQuick
import Quickshell
import qs.core
import qs.platform.system
import qs.domain.launcher
import qs.domain.config
import qs.domain.notifications
import qs.domain.diagnostics
import qs.domain.backend
import qs.domain.surfaces
import qs.domain.surfaces.place
import qs.domain.theme
import qs.domain.shortcuts
import qs.domain.sidebar

ShellRoot {
    id: root

    // Per-output overrides, one watcher per connected screen.
    MonitorConfigLoader {}

    // The applications' light and dark, kept with the shell's -- opt-in, under
    // `theme.desktop.followMode`, and it does nothing at all while that is off.
    DesktopVariant {}

    // The screen edge that opens the sidebar, kept on the side the sidebar is
    // on. Does nothing until `sidebar.position` changes, and nothing at all
    // when no edge is bound to the sidebar.
    SidebarEdge {}

    // Every screen's surfaces, the panel first.
    ShellScreens {}

    ShellWindows {
        id: windows
    }

    ShellIpc {}

    // "Open this where the pointer is", from the KWin script the CLI loads.
    // Nothing else can answer the question on Wayland; see PointerRequests.
    Connections {
        target: PointerRequests

        function onRequested(action, x, y, output) {
            const name = output.length > 0 ? output
                : (Quickshell.screens.find(s => Place.contains(s, x, y))?.name ?? "");
            if (action === "clipboard")
                Surfaces.openClipboardAt(x, y, output);
            else if (action === "sidebar")
                Surfaces.toggleSidebar(name);
        }
    }

    // This shell's own keys, straight off kglobalaccel -- see ShortcutWatch
    // for what that replaces. The same verbs the IPC handlers call (ShellIpc,
    // ShellWindows), so a key and `rmpr <thing>` cannot come to mean
    // different things.
    Connections {
        target: ShortcutWatch

        function onPressed(action) {
            switch (action) {
            case "launcher": LauncherService.toggle("apps"); break;
            case "search":   LauncherService.toggle("search"); break;
            case "settings": windows.toggleSettings(); break;
            case "keys":     Surfaces.toggleKeys(""); break;
            case "switcher":         Surfaces.openWindowSwitcher("", 1); break;
            case "switcher-reverse": Surfaces.openWindowSwitcher("", -1); break;
            case "overview":         Surfaces.openOverview("", 1); break;
            case "overview-reverse": Surfaces.openOverview("", -1); break;
            }
        }

        // Only the held ones have a release worth hearing: Alt+Tab chooses
        // when Alt comes up. It arrives on the same connection as the press
        // now, so it cannot overtake it -- which is what it used to do.
        function onReleased(action) {
            switch (action) {
            case "switcher":
            case "switcher-reverse":
            case "overview":
            case "overview-reverse":
                Surfaces.commitHeld();
                break;
            }
        }
    }

    // Quickshell restarts itself after a crash without systemd noticing, so
    // the only thing that can report one is the shell that came back.
    // Referenced here so it runs at startup rather than whenever something
    // first happens to look at it.
    readonly property string _lastCrash: CrashWatch.reported

    // Referenced so the eavesdrop starts with the shell when it is wanted,
    // rather than the first time a widget happens to look at it.
    readonly property bool _notificationsWanted: NotificationWatch.enabled

    // Referenced so Plasma's tray-only services are looked after from the
    // moment the shell starts. Under our renderer, without this, every
    // notification is dropped: see PlasmaServices.
    readonly property var _plasmaServices: PlasmaServices.decision

    Component.onCompleted: {
        // Reading the environment belongs to the platform layer, not to core,
        // so the logger is configured here rather than reaching for it itself.
        Log.debugEnabled = Env.debug();
        Log.info("shell", `${Branding.displayName} ${Branding.version} started`);
    }
}
