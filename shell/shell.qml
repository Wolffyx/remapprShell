pragma ComponentBehavior: Bound

// Composition root. It wires features together and owns no logic of its own --
// every behaviour lives in a layer below (see scripts/lint-layers.sh).

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.features.panel
import qs.features.panel.model
import qs.platform.system
import qs.domain.launcher
import qs.domain.config
import qs.features.settings
import qs.features.wizard

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
