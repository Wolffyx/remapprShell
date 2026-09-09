pragma ComponentBehavior: Bound

// Composition root. It wires features together and owns no logic of its own --
// every behaviour lives in a layer below (see scripts/lint-layers.sh).

import QtQuick
import Quickshell
import qs.core
import qs.features.panel
import qs.platform.system

ShellRoot {
    id: root

    // One panel per screen. Variants rebuilds the set on monitor hotplug, so
    // nothing here has to watch for display changes.
    Variants {
        model: Quickshell.screens

        Panel {}
    }

    Component.onCompleted: {
        // Reading the environment belongs to the platform layer, not to core,
        // so the logger is configured here rather than reaching for it itself.
        Log.debugEnabled = Env.debug();
        Log.info("shell", `${Branding.displayName} ${Branding.version} started`);
    }
}
