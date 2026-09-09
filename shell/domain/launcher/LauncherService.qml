pragma Singleton

// Chooses which launcher opens, and is the only thing that decides.
//
// The panel button, any keybinding and `rmpr launcher` all call open() here,
// so a provider can be swapped in configuration without touching anything that
// triggers a launcher.

import QtQuick
import qs.core
import qs.domain.config
import qs.domain.launcher.providers

QtObject {
    id: root

    readonly property string configured: ConfigStore.value("launcher.provider", "auto")

    readonly property BuiltinProvider builtin: BuiltinProvider {}

    readonly property KRunnerProvider krunner: KRunnerProvider {}

    readonly property KickoffProvider kickoff: KickoffProvider {
        mode: ConfigStore.value("launcher.kickoffMode", "menu")
    }

    readonly property ExecProvider fuzzel: ExecProvider {
        providerId: "fuzzel"
        label: "fuzzel"
        command: ["fuzzel"]
    }

    readonly property ExecProvider rofi: ExecProvider {
        providerId: "rofi"
        label: "rofi"
        command: ["rofi", "-show", "drun"]
    }

    readonly property ExecProvider custom: ExecProvider {
        providerId: "custom"
        label: "Custom command"
        command: ConfigStore.value("launcher.command", [])
    }

    readonly property var providers: [root.builtin, root.krunner, root.kickoff,
                                      root.fuzzel, root.rofi, root.custom]

    readonly property var availableProviders: root.providers.filter(p => p.available)

    // Preference order when nothing is configured. The built-in is last on
    // purpose: on a KDE desktop, KRunner and Kickoff are what the user already
    // knows, and this shell exists to work with them rather than replace them.
    readonly property var autoOrder: ["krunner", "kickoff", "builtin"]

    readonly property Provider active: {
        if (root.configured !== "auto") {
            const chosen = root.providers.find(p => p.providerId === root.configured);
            if (chosen && chosen.available)
                return chosen;
            if (chosen)
                Log.warn("launcher", `provider '${root.configured}' is not available here; falling back`);
            else
                Log.warn("launcher", `no launcher provider named '${root.configured}'; falling back`);
        }

        for (const id of root.autoOrder) {
            const p = root.providers.find(q => q.providerId === id && q.available);
            if (p)
                return p;
        }
        return root.builtin;
    }

    // Which launcher will actually open is a decision made from configuration
    // and availability, so it is reported once rather than left to be guessed
    // from behaviour.
    onActiveChanged: Log.info("launcher", `using '${root.active.providerId}' (configured: ${root.configured}; available: ${root.availableProviders.map(p => p.providerId).join(", ") || "none"})`)

    function open(mode) { root.active.open(mode ?? "apps"); }
    function openWithQuery(q) { root.active.openWithQuery(q); }
    function close() { root.active.close(); }
    function toggle(mode) { root.active.toggle(mode); }
}
