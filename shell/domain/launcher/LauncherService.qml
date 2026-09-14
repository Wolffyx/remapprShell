pragma Singleton

// Chooses which launcher opens, and is the only thing that decides.
//
// The panel button, any keybinding and `rmpr launcher` all call open() here,
// so a provider can be swapped in configuration without touching anything that
// triggers a launcher.
//
// Opening the application menu and searching are different acts and get
// different providers. On KDE the start button should give you Kickoff and
// Meta+Space should give you KRunner; treating both as one "launcher" choice
// means one of them is always wrong. So there are two settings, and `mode`
// decides which applies:
//
//   apps            the start menu       launcher.provider
//   search, run     type-to-find         launcher.searchProvider

import QtQuick
import qs.core
import qs.domain.config
import qs.domain.launcher.providers

QtObject {
    id: root

    readonly property string configuredApps: ConfigStore.value("launcher.provider", "auto")
    readonly property string configuredSearch: ConfigStore.value("launcher.searchProvider", "auto")

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

    // Preference when nothing is configured. The built-in first, both times.
    //
    // KDE's own used to come first, on the reasoning that this shell exists to
    // work with them rather than replace them. That reasoning was right and
    // the order was still wrong, because "available" does not mean the same
    // thing for all of them. Kickoff is an applet inside whichever shell
    // package plasmashell is running: it reports itself available whenever
    // Plasma is there, and opens nothing at all when plasmashell is running
    // somebody else's package. A profile that lost `launcher.provider` fell
    // back to auto, auto chose kickoff, and the start menu and the search both
    // did nothing with no error anywhere.
    //
    // The built-in is drawn by this shell and has no such dependency, so it is
    // the only one whose availability is worth as much as it claims. Auto
    // means "the one that will work"; naming kickoff or krunner explicitly
    // still picks them.
    readonly property var autoOrderApps: ["builtin", "kickoff", "krunner"]
    readonly property var autoOrderSearch: ["builtin", "krunner", "kickoff"]

    function _resolve(configured, order, what) {
        if (configured !== "auto") {
            const chosen = root.providers.find(p => p.providerId === configured);
            if (chosen && chosen.available)
                return chosen;
            if (chosen)
                Log.warn("launcher", `${what} provider '${configured}' is not available here; falling back`);
            else
                Log.warn("launcher", `no launcher provider named '${configured}'; falling back`);
        }
        for (const id of order) {
            const p = root.providers.find(q => q.providerId === id && q.available);
            if (p)
                return p;
        }
        return root.builtin;
    }

    readonly property Provider appsProvider: root._resolve(root.configuredApps, root.autoOrderApps, "menu")
    readonly property Provider searchProvider: root._resolve(root.configuredSearch, root.autoOrderSearch, "search")

    function providerFor(mode) {
        return mode === "search" || mode === "run" ? root.searchProvider : root.appsProvider;
    }

    // What the panel button opens, and therefore what may own a popout.
    readonly property Provider active: root.appsProvider

    // Which launcher will actually open is a decision made from configuration
    // and availability, so it is reported once rather than left to be guessed
    // from behaviour.
    onAppsProviderChanged: Log.info("launcher", `menu: '${root.appsProvider.providerId}' (configured: ${root.configuredApps}; available: ${root.availableProviders.map(p => p.providerId).join(", ") || "none"})`)
    onSearchProviderChanged: Log.info("launcher", `search: '${root.searchProvider.providerId}' (configured: ${root.configuredSearch})`)

    function open(mode) {
        const m = mode ?? "apps";
        root.providerFor(m).open(m);
    }

    // A query is a search by definition, so it always goes to the search
    // provider regardless of which mode the caller thought it was in.
    function openWithQuery(q) { root.searchProvider.openWithQuery(q); }

    function close() {
        root.appsProvider.close();
        if (root.searchProvider !== root.appsProvider)
            root.searchProvider.close();
    }

    function toggle(mode) {
        const m = mode ?? "apps";
        root.providerFor(m).toggle(m);
    }
}
