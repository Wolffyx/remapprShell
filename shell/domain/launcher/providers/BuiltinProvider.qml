// The launcher that ships with the shell: the start menu and the search the
// design draws.
//
// It holds only state and decisions -- the query, what it finds, which layout,
// whether the menu or the search is open -- and does what is chosen. The
// windows that show it live in the feature layer, because domain code must
// not draw. That split is also why this is the one provider whose popup can
// be anchored to the panel button: it is our own window.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.domain.config
import qs.domain.launcher
import qs.domain.launcher.actions
import qs.domain.launcher.apps
import qs.domain.session
import qs.domain.surfaces
import qs.platform.kde

Provider {
    id: root

    providerId: "builtin"
    label: "Built-in launcher"
    available: true
    embedded: true

    property string query: ""
    property int selectedIndex: 0
    property int maxResults: 8

    // "apps": the start menu, under its button. "search": the search, over
    // the whole screen.
    property string mode: "apps"

    // Which screen the launcher belongs to while it is open.
    //
    // The panel exists once per monitor, so without this every screen builds
    // its own popout and they all try to grab the keyboard at once. Wayland
    // grants the grab to one and refuses the rest, which leaves a launcher on
    // screen that cannot be typed into.
    property string shownOn: ""

    readonly property string layout: {
        const l = ConfigStore.value("launcher.layout", "twopane");
        return l === "grid" || l === "list" ? l : "twopane";
    }
    readonly property string prefix: ConfigStore.value("launcher.actionPrefix", ">") ?? ">"
    readonly property bool dense: ConfigStore.value("launcher.dense", false) === true
    readonly property bool hints: ConfigStore.value("launcher.hints", true) !== false

    // Applications, minus the ones that ask not to be shown.
    readonly property var applications: DesktopEntries.applications.values
        .filter(a => a && !a.noDisplay)

    // What was pinned, in its order -- or, with nothing pinned, one of each
    // thing most people open every day, from what is installed.
    readonly property var pinnedIds: ConfigStore.value("launcher.pinned", []) ?? []
    readonly property var pinnedApps: root.pinnedIds.length > 0
        ? Apps.resolvePinned(root.applications, root.pinnedIds)
        : Apps.pickPinned(root.applications, 10)

    // Every desktop entry hands its fields over through this.
    //
    // `keywords` is a list, and a QML list is not a JS array: `Array.isArray`
    // says false and `.toLowerCase` is not there, so a first fix that tested
    // for an array still threw on every query. String() copes with whatever
    // the type actually is -- a list arrives comma-joined, which is exactly
    // what a substring match wants.
    function _lower(value) {
        return String(value ?? "").toLowerCase();
    }

    // Ranked, not merely filtered: a prefix match on the name is almost
    // always what was meant, and burying it under an alphabetical list of
    // substring matches makes the launcher feel wrong even when the right
    // entry is present.
    function rank(q) {
        const scored = [];
        for (const app of root.applications) {
            const name = root._lower(app.name);
            let score = -1;
            if (name === q) score = 0;
            else if (name.startsWith(q)) score = 1;
            else if (name.includes(q)) score = 2;
            else if (root._lower(app.genericName).includes(q)) score = 3;
            else if (root._lower(app.keywords).includes(q)) score = 4;
            if (score >= 0)
                scored.push({ app: app, score: score, name: name });
        }
        scored.sort((a, b) => a.score !== b.score ? a.score - b.score : a.name.localeCompare(b.name));
        return scored.slice(0, root.maxResults).map(s => s.app);
    }

    function appItem(app) {
        return { kind: "app", app: app, name: app.name, icon: app.icon ?? "",
                 description: app.genericName || app.comment || "" };
    }

    function sumItem(text) {
        const answer = Actions.formatNumber(Actions.evaluate(text));
        return { kind: "sum", name: `= ${answer}`, value: answer, glyph: "calculate",
                 description: "Enter copies the answer" };
    }

    // Everything the menu and the search offer for what was typed, in the
    // order they offer it: with the action prefix, a sum and then the
    // actions; without, a sum and then applications. With nothing typed the
    // search suggests the pinned applications; the menu shows its own.
    readonly property var results: {
        const parsed = Actions.parse(root.query, root.prefix);
        const out = [];
        if (parsed.actions) {
            if (Actions.isSum(parsed.text))
                out.push(root.sumItem(parsed.text));
            for (const a of Actions.match(parsed.text))
                out.push({ kind: "action", action: a, name: a.name, glyph: a.glyph, description: a.description });
            return out;
        }
        if (parsed.text.length === 0)
            return root.mode === "search" ? root.pinnedApps.slice(0, root.maxResults).map(root.appItem) : [];
        if (Actions.isSum(parsed.text))
            out.push(root.sumItem(parsed.text));
        return out.concat(root.rank(root._lower(parsed.text)).map(root.appItem));
    }

    function open(mode) {
        root.mode = mode === "search" || mode === "run" ? "search" : "apps";
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
        root.open("search");
        root.query = q;
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
        const item = root.results[root.selectedIndex];
        if (!item) {
            Log.debug("launcher", `nothing to do for '${root.query}'`);
            return;
        }
        root.activate(item);
    }

    function activate(item) {
        if (!item)
            return;
        if (item.kind === "app")
            root.launch(item.app);
        else if (item.kind === "action")
            root.run(item.action.id);
        else if (item.kind === "sum") {
            root.copy(item.value);
            root.close();
        }
    }

    function launch(app) {
        if (!app)
            return;
        Log.info("launcher", `launching ${app.id}`);
        app.execute();
        root.close();
    }

    function _cycle(key, order, fallback) {
        const current = ConfigStore.value(key, fallback);
        ConfigStore.set(key, order[(order.indexOf(current) + 1) % order.length]);
    }

    // What each action does. The shell's own colours are its configuration;
    // the rest is asked of Plasma, KWin or logind, as a key would ask.
    function run(id) {
        if (id === "calculator") {
            root.query = `${root.prefix}`;
            return;
        }
        const screen = root.shownOn;
        root.close();
        switch (id) {
        case "scheme":
            root._cycle("theme.mode", ["auto", "light", "dark"], "auto");
            break;
        case "variant":
            root._cycle("theme.accent", ["plasma", "blue", "teal", "magenta", "orange"], "plasma");
            break;
        case "dark":
        case "light":
            ConfigStore.set("theme.mode", id);
            break;
        case "wallpaper":
            PlasmaApplets.openSettings("kcm_wallpaper");
            break;
        case "settings":
            Quickshell.execDetached([Branding.ctlBin, "settings"]);
            break;
        case "taskview":
            Quickshell.execDetached(["busctl", "--user", "call", "org.kde.kglobalaccel", "/component/kwin",
                                     "org.kde.kglobalaccel.Component", "invokeShortcut", "s", "Overview"]);
            break;
        case "sidebar":
            Surfaces.toggleSidebar(screen);
            break;
        case "keys":
            Surfaces.toggleKeys(screen);
            break;
        case "lock":
            Session.lock();
            break;
        case "suspend":
            Session.suspend();
            break;
        case "logout":
            Session.prompt("promptLogout");
            break;
        case "reboot":
            Session.prompt("promptReboot");
            break;
        case "shutdown":
            Session.prompt("promptShutDown");
            break;
        default:
            Log.warn("launcher", `no action named '${id}'`);
        }
    }

    // A sum's answer onto the clipboard: through wl-copy's stdin, as the
    // clipboard widget does, so it is never in a process's arguments.
    property string _pending: ""

    function copy(text) {
        root._pending = String(text ?? "");
        copier.running = false;
        copier.stdinEnabled = true;
        copier.running = true;
    }

    readonly property Process _copier: Process {
        id: copier
        command: ["wl-copy"]
        stdinEnabled: true
        onStarted: {
            copier.write(root._pending);
            root._pending = "";
            copier.stdinEnabled = false;
        }
    }
}
