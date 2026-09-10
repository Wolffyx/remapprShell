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
