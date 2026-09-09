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
    IpcHandler {
        target: "launcher"

        function toggle(): void { LauncherService.toggle("apps"); }
        function open(): void { LauncherService.open("apps"); }
        function close(): void { LauncherService.close(); }
        function query(text: string): void { LauncherService.openWithQuery(text); }
        function provider(): string { return LauncherService.active.providerId; }
    }

    Component.onCompleted: {
        // Reading the environment belongs to the platform layer, not to core,
        // so the logger is configured here rather than reaching for it itself.
        Log.debugEnabled = Env.debug();
        Log.info("shell", `${Branding.displayName} ${Branding.version} started`);
    }
}
