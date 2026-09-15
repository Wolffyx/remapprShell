pragma ComponentBehavior: Bound

// Composition root. It wires features together and owns no logic of its own --
// every behaviour lives in a layer below (see scripts/lint-layers.sh).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.core
import qs.features.panel
import qs.features.panel.model
import qs.platform.system
import qs.domain.launcher
import qs.domain.osd
import qs.domain.config
import qs.features.osd
import qs.features.notifications
import qs.features.settings
import qs.features.switchers
import qs.features.wizard
import qs.domain.notifications
import qs.domain.diagnostics
import qs.domain.status
import qs.domain.backend
import qs.domain.windows
import qs.features.diagnostics
import qs.features.launcher
import qs.features.desktop
import qs.features.overlays
import qs.domain.surfaces
import qs.domain.theme

ShellRoot {
    id: root

    // One panel per screen. Variants rebuilds the set on monitor hotplug, so
    // nothing here has to watch for display changes.
    // Per-output overrides, one watcher per connected screen.
    MonitorConfigLoader {}

    // The applications' light and dark, kept with the shell's -- opt-in, under
    // `theme.desktop.followMode`, and it does nothing at all while that is off.
    DesktopVariant {}

    // Drawn only when this renderer is the one selected. The Plasma renderer
    // draws the same panel through plasmashell, and both drawing at once is
    // the two-panels-at-one-edge bug the renderer key exists to prevent -- so
    // the check lives here, where the panels are created, rather than in
    // anything that could be forgotten.
    Variants {
        // Not until the profile has been read: the defaults name this shell
        // as what draws the panel, so a profile that names Plasma instead
        // would otherwise get a panel for one frame and then lose it.
        model: ConfigStore.profileLoaded && PanelModel.renderer === "quickshell"
            ? Quickshell.screens : []

        Panel {}
    }

    // Lets a keybinding or `rmpr launcher` open whatever the panel button
    // would open. Reimplementing the choice in the CLI would let the two drift
    // apart, which is exactly the sort of thing nobody notices until it is
    // confusing.
    // Built only when first opened: a settings window nobody has asked for
    // should cost nothing at startup.
    LazyLoader {
        id: settings
        loading: false

        SettingsWindow {
            id: settingsWindow
            visible: true
            sections: Schema.sections

            // FloatingWindow has no `closed` signal; the window going invisible
            // is how a close reaches us, and unloading then means reopening
            // starts fresh rather than restoring the last page.
            onVisibleChanged: if (!visible) settings.activeAsync = false
        }
    }

    // The built-in search, over the screen it was opened on -- the first one
    // when it was opened from a key.
    Variants {
        model: LauncherService.builtin.visible && LauncherService.builtin.mode === "search"
            ? Quickshell.screens.filter(s => s.name === (LauncherService.builtin.shownOn || (Quickshell.screens[0]?.name ?? "")))
            : []

        SearchOverlay {}
    }

    // The sidebar, the key sheet and the session screen: one at a time, on
    // the screen they were asked for on (Surfaces).
    Variants {
        model: Surfaces.sidebar ? Quickshell.screens.filter(s => s.name === Surfaces.screenName) : []
        Sidebar {}
    }

    Variants {
        model: Surfaces.keys ? Quickshell.screens.filter(s => s.name === Surfaces.screenName) : []
        KeysOverlay {}
    }

    Variants {
        model: Surfaces.session ? Quickshell.screens.filter(s => s.name === Surfaces.screenName) : []
        SessionOverlay {}
    }

    // Alt+Tab, when `switching.windows` says this shell draws it.
    Variants {
        model: Surfaces.windowSwitcher ? Quickshell.screens.filter(s => s.name === Surfaces.screenName) : []
        WindowSwitcher {}
    }

    // Meta+Tab, when `switching.desktops` says this shell draws it rather than
    // KWin's Overview.
    Variants {
        model: Surfaces.overview ? Quickshell.screens.filter(s => s.name === Surfaces.screenName) : []
        Overview {}
    }

    // The desktop's own two: a rounded frame over the screen's corners, and a
    // clock on the wallpaper. Both off by default, both drawn only where they
    // are asked for, and neither takes a click or reserves a pixel.
    Variants {
        model: ConfigStore.value("desktop.border", false) === true ? Quickshell.screens : []

        ScreenBorder {}
    }

    Variants {
        model: ConfigStore.value("desktop.clock", false) === true ? Quickshell.screens : []

        DesktopClock {}
    }

    // Off unless asked for, and built only then: Plasma's OSD already works,
    // and this exists for someone who wants a layer-shell one instead.
    Variants {
        model: OsdService.enabled ? Quickshell.screens.slice(0, 1) : []

        OsdOverlay {}
    }

    // This shell's own notification popups: only when notifications.server
    // is "shell" and its server really holds the name. Off by default; Plasma
    // draws them otherwise. One screen, as the OSD.
    Variants {
        model: ShellNotifications.active ? Quickshell.screens.slice(0, 1) : []

        NotificationPopups {}
    }

    // Shown once, on a machine that has never run it. The marker lives in the
    // state directory rather than in the profile: a profile with no overrides
    // in it is an ordinary thing to have, so "the config is empty" cannot be
    // the signal for "this person has never seen this".
    LazyLoader {
        id: wizard
        loading: false

        WizardWindow {
            visible: true
            onFinished: wizard.activeAsync = false
            onVisibleChanged: if (!visible) wizard.activeAsync = false
        }
    }

    FileView {
        path: Paths.wizardDoneFile
        printErrors: false

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                Log.info("wizard", "first run; showing the wizard");
                wizard.activeAsync = true;
            }
        }
    }

    // The consent window for AI assist, on one report. Opened by `rmpr ask`
    // when it has no terminal to ask in, and by the widget's Ask button
    // through the same command -- so there is exactly one way to send.
    LazyLoader {
        id: ask
        loading: false

        AskWindow {
            visible: true
            reportName: askReport.name
            onVisibleChanged: if (!visible) ask.activeAsync = false
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

    IpcHandler {
        target: "services"

        function status(): string { return JSON.stringify(PlasmaServices.summary()); }
        function reconcile(): void { PlasmaServices.reconcile(); }
        function rehost(): void { PlasmaServices.rehost(); }
    }

    // What the tray host can see, which is otherwise only knowable by looking
    // at the panel. `doctor` reads it, and so does anyone working out why an
    // application's icon is not where they expected.
    IpcHandler {
        target: "tray"

        function list(): string {
            const out = [];
            for (const item of SystemTray.items?.values ?? []) {
                if (!item)
                    continue;
                out.push({
                    id: item.id,
                    title: item.title,
                    tooltip: item.tooltipTitle,
                    status: item.status,
                    category: item.category,
                    hasMenu: item.hasMenu,
                    onlyMenu: item.onlyMenu
                });
            }
            return JSON.stringify(out);
        }

        function count(): string { return String(SystemTray.items?.values?.length ?? 0); }
    }

    // A left click on a widget by name: opens its popout, or does whatever
    // that widget does when clicked. The screen defaults to the first one.
    IpcHandler {
        target: "panel"

        function click(widgetId: string, screen: string): string {
            const name = screen || (Quickshell.screens[0]?.name ?? "");
            PanelModel.clickRequested(widgetId, name);
            return name;
        }

        // Its tooltip, for a few seconds, as if the pointer had rested on it.
        function tooltip(widgetId: string, screen: string): string {
            const name = screen || (Quickshell.screens[0]?.name ?? "");
            PanelModel.tooltipRequested(widgetId, name);
            return name;
        }

        // The panel's own right-click menu, as if the pointer had opened it on
        // empty panel. `at` is how far along the panel the click was; -1, the
        // default, centres it. The only way to open this without a mouse, and
        // the only way a session with no pointer can see whether it opens at
        // all -- which is how "a right click on the bottom of the taskbar does
        // nothing" was told apart from "it opens the menu I did not expect".
        function menu(screen: string, at: string): string {
            const name = screen || (Quickshell.screens[0]?.name ?? "");
            const along = at ? parseFloat(at) : -1;
            PanelModel.menuRequested(name, isNaN(along) ? -1 : along);
            return name;
        }

        function closeMenu(): void { PanelModel.closeOpenMenu(); }

        function screens(): string { return Quickshell.screens.map(s => s.name).join("\n"); }

        // Where each shown widget is on that screen's panel, in screen
        // coordinates, in the order the zones hold them.
        function layout(screen: string): string {
            const name = screen || (Quickshell.screens[0]?.name ?? "");
            return JSON.stringify(PanelModel.slots
                .filter(s => s && s.screenName === name && s.visible)
                .map(s => {
                    const p = s.mapToItem(null, 0, 0);
                    return { id: s.entry?.id ?? "", x: Math.round(p.x), y: Math.round(p.y),
                             w: Math.round(s.width), h: Math.round(s.height) };
                }));
        }
    }

    // What the status widgets are reading, as they read it. The same question
    // as the tray's: when an icon on the panel looks wrong, this says whether
    // the widget is drawing its input wrongly or the input is what is wrong.
    IpcHandler {
        target: "status"

        function audio(): string { return JSON.stringify(AudioStatus.summary()); }
        function network(): string { return JSON.stringify(NetworkStatus.summary()); }
        function bluetooth(): string { return JSON.stringify(BluetoothStatus.summary()); }
        function power(): string { return JSON.stringify(PowerStatus.summary()); }
        function media(): string { return JSON.stringify(MediaStatus.summary()); }
        function clipboard(): string { return JSON.stringify(ClipboardStatus.summary()); }
        function brightness(): string { return JSON.stringify(BrightnessStatus.summary()); }
        function keyboard(): string { return JSON.stringify(KeyboardStatus.summary()); }
        function privacy(): string { return JSON.stringify(PrivacyStatus.summary()); }

        // Which window each monitor's panel names, and which windows are
        // asking for attention.
        function windows(): string {
            return JSON.stringify({
                count: WindowsService.windows.length,
                perScreen: Object.keys(WindowsService.lastActiveByOutput).map(o => ({
                    screen: o,
                    title: WindowsService.windowFor(o)?.title ?? ""
                })),
                attention: WindowsService.windows.filter(w => w.attention).map(w => w.title)
            });
        }
    }

    // What the brightness widget does on a scroll and a middle click, for
    // working on it without a pointer. Both go through the widget's own
    // service, so they prove the same path a hand on the wheel would take.
    IpcHandler {
        target: "brightness"

        function step(steps: string, percent: string): string {
            BrightnessStatus.step(parseFloat(steps) || 0, parseInt(percent, 10) || 5);
            return JSON.stringify(BrightnessStatus.displays.map(d => [d.name, d.brightness]));
        }
        function nightLight(): string {
            BrightnessStatus.toggleNightLight();
            return BrightnessStatus.nightState;
        }
    }

    // Opens the clipboard widget's popout, for a shortcut: the first one on
    // any panel, since a keypress has no position to say which screen.
    IpcHandler {
        target: "clipboard"

        function toggle(): string {
            const slot = PanelModel.slots.find(s => s && s.visible && s.entry?.id === "clipboard");
            if (!slot)
                return "no clipboard widget on the panel";
            PanelModel.clickRequested("clipboard", slot.screenName);
            return slot.screenName;
        }
    }

    // The runtime layer of the configuration: in memory only, above the
    // profile, gone when the shell stops. Nothing set here is written
    // anywhere, which makes it the way to try a layout without committing to
    // it -- or to have a second copy of the shell draw a panel while the
    // profile says another renderer is in charge.
    //
    // `quickshell ipc call` reads an argument that starts with `[` as a list
    // of arguments, so a JSON array must be passed with a leading space:
    // `setRuntime bar.entries ' [{"id":"clock","zone":"middle"}]'`.
    IpcHandler {
        target: "config"

        function get(path: string): string { return JSON.stringify(ConfigStore.value(path, null)); }

        function setRuntime(path: string, json: string): string {
            let value;
            try {
                value = JSON.parse(json);
            } catch (e) {
                return `not JSON: ${e.message}`;
            }
            ConfigStore.setRuntime(path, value);
            return JSON.stringify(ConfigStore.value(path, null));
        }

        function clearRuntime(): void { ConfigStore.clearRuntime(); }
    }

    IpcHandler {
        target: "notifications"

        // JSON, because a notification is a record and IPC returns strings.
        function at(index: string): string {
            const entry = NotificationWatch.entries[parseInt(index, 10) || 0];
            return entry ? JSON.stringify(entry) : "";
        }
        function last(): string { return at("0"); }
        function count(): string { return String(NotificationWatch.entries.length); }
        function list(): string { return JSON.stringify(NotificationWatch.entries); }
        function clear(): void { NotificationWatch.clear(); }

        // This shell's own server (notifications.server "shell").
        function server(): string { return JSON.stringify(ShellNotifications.summary()); }
        function dnd(state: string): string { return ShellNotifications.setDnd(state) ? "on" : "off"; }
        function dismissAll(): void { ShellNotifications.dismissAll(); }
        // renderer.sh, before switching to a renderer with a Plasma tray.
        function release(): void { PlasmaServices.releaseNotifications(); }
    }

    IpcHandler {
        target: "ask"

        function open(report: string): void {
            // A fresh window each time: the report it shows is a property set
            // at construction, and reopening on a different one must not show
            // the old bundle for a frame.
            ask.activeAsync = false;
            askReport.name = report;
            ask.activeAsync = true;
        }
        function close(): void { ask.activeAsync = false; }
    }

    QtObject {
        id: askReport
        property string name: ""
    }

    // Quickshell reloads by itself only for files the config imported when it
    // loaded. A widget's own files come in later, through a Loader, and so
    // does a singleton only a widget uses; editing one of those changes
    // nothing on screen until this is called. Measured, not assumed: an edit
    // to the show-desktop widget and to Desktops.qml sat unloaded for minutes
    // while the running shell looked current.
    IpcHandler {
        target: "shell"

        function reload(): void { Quickshell.reload(false); }

        // Debug logging, without a restart. The faults worth logging are the
        // ones that happen on a real keyboard under real load, and restarting
        // to enable logging is restarting away the state that caused them.
        function debug(on: string): string {
            Log.debugEnabled = on !== "false" && on !== "0" && on !== "off";
            return Log.debugEnabled ? "debug logging on" : "debug logging off";
        }
    }

    // The sidebar, the key sheet and the session screen, from a key: `rmpr
    // sidebar`, `rmpr keys`, bound with `rmpr shortcuts set`.
    IpcHandler {
        target: "surfaces"

        function sidebar(): void { Surfaces.toggleSidebar(""); }
        function keys(): void { Surfaces.toggleKeys(""); }
        function session(kind: string): void { Surfaces.openSession(kind || "promptAll", ""); }
        function switcher(): void { Surfaces.openWindowSwitcher("", 1); }
        function switcherReverse(): void { Surfaces.openWindowSwitcher("", -1); }
        function overview(): void { Surfaces.openOverview("", 1); }
        function overviewReverse(): void { Surfaces.openOverview("", -1); }

        // The switcher's key coming up, from the session daemon. See
        // Surfaces.commitHeld.
        function switcherCommit(): void { Surfaces.commitHeld(); }
        function close(): void { Surfaces.closeAll(); }
    }

    IpcHandler {
        target: "wizard"

        function open(): void { wizard.activeAsync = true; }
        function close(): void { wizard.activeAsync = false; }
    }

    IpcHandler {
        target: "settings"

        function open(): void { settings.activeAsync = true; }
        function close(): void { settings.activeAsync = false; }
        function toggle(): void { settings.activeAsync = !settings.activeAsync; }

        // Opens on a named page. The names are the schema's section ids, which
        // are also the headings in the generated configuration reference, so
        // there is one set of names for the window, the CLI and the docs.
        function page(name: string): string {
            const sections = Schema.sections ?? [];

            // Asked for in the first seconds after the shell starts, the
            // schema file has not been read yet and no page exists to find.
            // The window remembers the name and lands on it when the file
            // arrives; saying "no such page" here was a lie about the name.
            if (sections.length === 0) {
                settings.activeAsync = true;
                settings.item.requestedPage = name;
                return `${name} (opening once the schema loads)`;
            }

            const index = sections.findIndex(s => s && s.id === name);
            if (index < 0)
                return `no such page: ${name} (${sections.map(s => s.id).join(", ")})`;
            settings.activeAsync = true;
            settings.item.currentIndex = index;
            return name;
        }

        // The page names, for `rmpr settings pages`. Empty is not an answer,
        // so it says why it has none rather than printing nothing.
        function pages(): string {
            const sections = Schema.sections ?? [];
            if (sections.length === 0)
                return "the settings schema has not loaded yet";
            return sections.map(s => s.id).join("\n");
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { LauncherService.toggle("apps"); }
        function open(): void { LauncherService.open("apps"); }
        function search(): void { LauncherService.toggle("search"); }
        function close(): void { LauncherService.close(); }
        function query(text: string): void { LauncherService.openWithQuery(text); }
        function provider(): string { return LauncherService.appsProvider.providerId; }
        function searchProvider(): string { return LauncherService.searchProvider.providerId; }
    }

    Component.onCompleted: {
        // Reading the environment belongs to the platform layer, not to core,
        // so the logger is configured here rather than reaching for it itself.
        Log.debugEnabled = Env.debug();
        Log.info("shell", `${Branding.displayName} ${Branding.version} started`);
    }
}
