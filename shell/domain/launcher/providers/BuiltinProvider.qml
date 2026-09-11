// The launcher that ships with the shell.
//
// It holds only state -- query, results, visibility. The window that shows it
// lives in the feature layer, because domain code must not draw. That split is
// also why this is the one provider whose popup can be anchored to the panel
// button: it is our own window.

import QtQuick
import Quickshell
import qs.core
import qs.domain.launcher

Provider {
    id: root

    providerId: "builtin"
    label: "Built-in launcher"
    available: true
    embedded: true

    property string query: ""
    property int selectedIndex: 0
    property int maxResults: 8

    // Which screen the launcher belongs to while it is open.
    //
    // The panel exists once per monitor, so without this every screen builds
    // its own popout and they all try to grab the keyboard at once. Wayland
    // grants the grab to one and refuses the rest, which leaves a launcher on
    // screen that cannot be typed into.
    property string shownOn: ""

    // Applications, minus the ones that ask not to be shown.
    readonly property var applications: DesktopEntries.applications.values
        .filter(a => a && !a.noDisplay)

    readonly property var results: {
        const q = root.query.trim().toLowerCase();
        const apps = root.applications;

        if (q.length === 0) {
            return apps.slice()
                .sort((a, b) => a.name.localeCompare(b.name))
                .slice(0, root.maxResults);
        }

        // Ranked, not merely filtered: a prefix match on the name is almost
        // always what was meant, and burying it under an alphabetical list of
        // substring matches makes the launcher feel wrong even when the right
        // entry is present.
        // Everything a desktop entry hands over goes through this.
        //
        // `keywords` is a list, and a QML list is not a JS array: `Array.isArray`
        // says false and `.toLowerCase` is not there, so a first fix that
        // tested for an array still threw on every query. String() copes with
        // whatever the type actually is -- a list arrives comma-joined, which
        // is exactly what a substring match wants.
        const lower = value => String(value ?? "").toLowerCase();

        const scored = [];
        for (const app of apps) {
            const name = lower(app.name);
            const generic = lower(app.genericName);
            const keywords = lower(app.keywords);

            let score = -1;
            if (name === q) score = 0;
            else if (name.startsWith(q)) score = 1;
            else if (name.includes(q)) score = 2;
            else if (generic.includes(q)) score = 3;
            else if (keywords.includes(q)) score = 4;

            if (score >= 0)
                scored.push({ app: app, score: score, name: name });
        }

        scored.sort((a, b) => a.score !== b.score ? a.score - b.score
                                                  : a.name.localeCompare(b.name));
        return scored.slice(0, root.maxResults).map(s => s.app);
    }

    function open(mode) {
        root.query = "";
        root.selectedIndex = 0;
        // Opened without a screen -- from IPC or a keybinding -- so fall back
        // to the first one rather than showing it everywhere.
        if (root.shownOn.length === 0)
            root.shownOn = Quickshell.screens[0]?.name ?? "";
        root.visible = true;
    }

    function openOn(screenName, mode) {
        root.shownOn = screenName ?? "";
        root.open(mode);
    }

    function openWithQuery(q) {
        root.query = q;
        root.selectedIndex = 0;
        root.visible = true;
    }

    function close() {
        root.visible = false;
        root.query = "";
        root.shownOn = "";
    }

    function moveSelection(delta) {
        const count = root.results.length;
        if (count === 0)
            return;
        root.selectedIndex = ((root.selectedIndex + delta) % count + count) % count;
    }

    function activateSelected() {
        const app = root.results[root.selectedIndex];
        if (!app) {
            Log.debug("launcher", `nothing to launch for '${root.query}'`);
            return;
        }
        Log.info("launcher", `launching ${app.id}`);
        app.execute();
        root.close();
    }
}
