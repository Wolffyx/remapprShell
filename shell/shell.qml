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
import qs.features.settings
import qs.features.wizard
import qs.domain.notifications
import qs.domain.diagnostics
import qs.domain.status
import qs.domain.backend
import qs.domain.windows
import qs.features.diagnostics

ShellRoot {
    id: root

    // One panel per screen. Variants rebuilds the set on monitor hotplug, so
    // nothing here has to watch for display changes.
    // Per-output overrides, one watcher per connected screen.
    MonitorConfigLoader {}

    // Drawn only when this renderer is the one selected. The Plasma renderer
    // draws the same panel through plasmashell, and both drawing at once is
    // the two-panels-at-one-edge bug the renderer key exists to prevent -- so
    // the check lives here, where the panels are created, rather than in
    // anything that could be forgotten.
    Variants {
        model: PanelModel.renderer === "quickshell" ? Quickshell.screens : []

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

    // Off unless asked for, and built only then: Plasma's OSD already works,
    // and this exists for someone who wants a layer-shell one instead.
    Variants {
        model: OsdService.enabled ? Quickshell.screens.slice(0, 1) : []

        OsdOverlay {}
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
            const index = sections.findIndex(s => s && s.id === name);
            if (index < 0)
                return `no such page: ${name} (${sections.map(s => s.id).join(", ")})`;
            settings.activeAsync = true;
            settings.item.currentIndex = index;
            return name;
        }

        function pages(): string {
            return (Schema.sections ?? []).map(s => s.id).join("\n");
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
