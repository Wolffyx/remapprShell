pragma ComponentBehavior: Bound

// Composition root. It wires features together and owns no logic of its own --
// every behaviour lives in a layer below (see scripts/lint-layers.sh).

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.features.panel
import qs.platform.system
import qs.domain.launcher
import qs.domain.config
import qs.features.settings

ShellRoot {
    id: root

    // One panel per screen. Variants rebuilds the set on monitor hotplug, so
    // nothing here has to watch for display changes.
    Variants {
        model: Quickshell.screens

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
