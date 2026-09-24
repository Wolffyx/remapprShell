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
import qs.core
import qs.domain.config
import qs.domain.launcher
import qs.domain.launcher.actions
import qs.domain.launcher.apps
import qs.domain.session
import qs.domain.surfaces
import qs.domain.windows
import qs.platform.kde
import qs.platform.system

Provider {
    id: root

    providerId: "builtin"
    label: "Built-in launcher"
    available: true
    embedded: true

    property string query: ""
    property int selectedIndex: 0
    // As many rows as the card draws. It was eight while applications were
    // the only source; with windows and files beside them, a row lost to a
    // heading is a row of results lost.
    property int maxResults: 9

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

    // What the search looks through besides applications. A list rather than
    // a switch per source: the order is Results', and what a person wants to
    // say here is "not my files", not "files third".
    readonly property var sources: ConfigStore.value("launcher.searchSources",
                                                     ["apps", "windows", "files", "settings"]) ?? []

    function searches(source) { return root.sources.indexOf(source) >= 0; }

    // Whether what has been opened before counts towards what is offered.
    // Off means the list is the same for everybody -- which is a preference
    // some people hold, and the only way to make a shared machine's launcher
    // stop telling the room what you opened.
    readonly property bool learns: ConfigStore.value("launcher.learn", true) !== false

    function _history(kind, id) {
        return root.learns ? Frecency.historyFor(kind, id) : null;
    }

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

    // What a desktop entry offers to be matched on. `exec` is here because
    // people type the binary -- "nvim", "code" -- far more often than the name
    // somebody gave the entry.
    //
    // `pinned` and `preferred` are not matched on: they are what makes two
    // equally good matches order themselves the way this machine would. See
    // Rank.bonus.
    function fieldsFor(app) {
        return {
            name: app.name,
            generic: app.genericName || app.comment,
            keywords: app.keywords,
            exec: app.execString,
            id: app.id,
            pinned: root.pinnedIds.indexOf(app.id) >= 0,
            preferred: DefaultApps.isDefault(app.id)
        };
    }

    // Pinning, from the results rather than from a settings page: the moment
    // somebody knows which of eight terminals they meant is the moment they
    // are looking at all eight.
    //
    // It writes `launcher.pinned`, which is the same list the start menu
    // pins to -- one idea, not two -- so a thing pinned here is at the top of
    // the menu as well, and the search suggests it before anything is typed.
    function isPinned(app) {
        return !!app && root.pinnedIds.indexOf(app.id) >= 0;
    }

    function togglePin(app) {
        if (!app)
            return;
        const pinned = root.pinnedIds.slice();
        const at = pinned.indexOf(app.id);
        if (at >= 0)
            pinned.splice(at, 1);
        else
            pinned.push(app.id);
        ConfigStore.set("launcher.pinned", pinned);
        Log.info("launcher", `${at >= 0 ? "unpinned" : "pinned"} ${app.id}`);
    }

    // The selected row's application, when it has one -- what the pin key
    // acts on.
    readonly property var selectedApp: {
        const item = root.results[root.selectedIndex];
        return item?.kind === "app" ? item.app : null;
    }

    // Ranked, not merely filtered, and ranked by Rank -- a continuous score
    // plus what this machine's own history of opening the thing is worth.
    //
    // The scoring used to be five buckets with ties broken alphabetically,
    // which made the order independent of what anybody actually ran: "s" put
    // Settings above Spotify forever. The alphabet is still the tie-break,
    // but only between results of equal score, which two things rarely are
    // once a use has been recorded.
    function rank(q) {
        const now = Date.now();
        const scored = [];
        for (const app of root.applications) {
            const score = Rank.rank(q, root.fieldsFor(app), root._history("app", app.id), now);
            if (score !== Rank.none)
                scored.push({ app: app, score: score, name: root._lower(app.name) });
        }
        scored.sort((a, b) => a.score !== b.score ? b.score - a.score : a.name.localeCompare(b.name));
        return scored.slice(0, root.maxResults).map(s => s.app);
    }

    // What the search offers before anything is typed: what this machine
    // opens, most recently first, and the pinned applications behind it. An
    // empty launcher that already lists the four things you open every day is
    // most of what "it learned" feels like.
    readonly property var suggestedApps: {
        const byId = {};
        for (const app of root.applications)
            byId[app.id] = app;

        const now = Date.now();
        const used = (root.learns ? Object.keys(Frecency.entries) : [])
            .filter(k => k.startsWith("app:"))
            .map(k => ({ app: byId[k.slice(4)], history: Frecency.entries[k] }))
            .filter(e => !!e.app)
            .map(e => ({ app: e.app, weight: Rank.recency(e.history.uses, e.history.lastMs, now) }))
            .filter(e => e.weight > 0)
            .sort((a, b) => b.weight - a.weight)
            .map(e => e.app);

        // Pinned first, in the order they were pinned: that is somebody
        // having said outright which ones they mean, and it outranks what
        // they happened to open this morning.
        const out = [];
        for (const app of root.pinnedApps) {
            if (root.pinnedIds.indexOf(app.id) < 0)
                break;     // the stand-ins shown when nothing is pinned
            out.push(app);
        }
        for (const app of used.concat(root.pinnedApps)) {
            if (out.length >= root.maxResults)
                break;
            if (!out.some(a => a.id === app.id))
                out.push(app);
        }
        return out.slice(0, root.maxResults);
    }

    function appItem(app) {
        return { kind: "app", app: app, name: app.name, icon: app.icon ?? "",
                 description: app.genericName || app.comment || "" };
    }

    // An open window. The title is what is matched and drawn; which
    // application it belongs to is the line under it, because two windows of
    // the same editor are told apart by their titles alone.
    function windowItem(window, appName) {
        return { kind: "window", uuid: window.uuid, name: window.title || appName,
                 icon: WindowsService.iconFor(window),
                 description: appName };
    }

    function fileItem(file) {
        return { kind: "file", file: file, uri: file.uri, name: file.name,
                 glyph: file.folder ? "folder" : "description", description: file.dir };
    }

    // A page of this shell's own settings, by the name the window gives it.
    function settingItem(section) {
        return { kind: "setting", id: section.id, name: section.label,
                 glyph: section.glyph || "tune", description: section.description ?? "" };
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
    // Everything every source offers for what was typed, each scored the same
    // way, so a window and an application compete on merit rather than on
    // which list they came from. What survives is Results' to decide.
    function candidates(text) {
        const now = Date.now();
        const out = [];

        if (root.searches("apps")) {
            for (const app of root.applications) {
                const fields = root.fieldsFor(app);
                const score = Rank.rank(text, fields, root._history("app", app.id), now);
                if (score !== Rank.none)
                    out.push({ item: root.appItem(app), score: score, group: "app",
                               pinned: fields.pinned });
            }
        }

        // A window is worth finding by its title -- "the tab I left open" --
        // which nothing else here can match. No history: a window is a thing
        // that exists now, not a thing chosen before.
        if (root.searches("windows")) {
            for (const window of WindowsService.windows) {
                const appName = WindowsService.appNameFor(window);
                const score = Rank.rank(text, { name: window.title, generic: appName,
                                               id: window.appId, prose: true }, null, now);
                if (score !== Rank.none)
                    out.push({ item: root.windowItem(window, appName), score: score, group: "window" });
            }
        }

        if (root.searches("files")) {
            for (const file of RecentFiles.files) {
                const score = Rank.rank(text, { name: file.name, generic: file.dir },
                                        root._history("file", file.uri), now);
                if (score !== Rank.none)
                    out.push({ item: root.fileItem(file), score: score, group: "file" });
            }
        }

        // The settings window has twenty pages and nobody remembers which one
        // holds the panel's rounding. Searching them is what the window's own
        // search would be, without the window.
        if (root.searches("settings")) {
            for (const section of Schema.sections) {
                const score = Rank.rank(text, { name: section.label, generic: section.description, id: section.id },
                                        root._history("setting", section.id), now);
                if (score !== Rank.none)
                    out.push({ item: root.settingItem(section), score: score, group: "setting" });
            }
        }

        return out;
    }

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
        // Nothing typed: what this machine opens, with no heading over it --
        // a suggestion is not a search result.
        if (parsed.text.length === 0)
            return root.mode === "search" ? root.suggestedApps.map(root.appItem) : [];
        if (Actions.isSum(parsed.text))
            out.push(Object.assign(root.sumItem(parsed.text), { group: "sum" }));
        return out.concat(Results.merge(root.candidates(parsed.text), root.maxResults - out.length));
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
        Log.debug("launcher", `open: ${root.mode} on ${root.shownOn}`);
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
        if (root.visible)
            Log.debug("launcher", `close: was ${root.mode} on ${root.shownOn}`);
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
        else if (item.kind === "window")
            root.raise(item);
        else if (item.kind === "file")
            root.openFile(item);
        else if (item.kind === "setting")
            root.openSetting(item);
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
        // Before the launch, not after: the launch is the last thing that
        // happens to this provider before the window closes, and a history
        // written after it was written by a component being torn down.
        Frecency.record("app", app.id);
        Launch.entry(app);
        root.close();
    }

    // A window found by its title: brought to the front, on whichever desktop
    // it is on. KWin does the moving -- see WindowsService.
    function raise(item) {
        root.close();
        WindowsService.activate(item.uuid);
        Log.info("launcher", `raising ${item.uuid}`);
    }

    function openFile(item) {
        Frecency.record("file", item.uri);
        root.close();
        RecentFiles.open(item.file);
    }

    function openSetting(item) {
        Frecency.record("setting", item.id);
        root.close();
        Quickshell.execDetached([Branding.ctlBin, "settings", item.id]);
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
        // Actions are learned too, for when the ordering below them is ranked
        // rather than listed. Recorded even though Actions.match does not yet
        // read it: a history is only worth anything once it has been kept for
        // a while, and starting to keep it costs one line.
        Frecency.record("action", id);
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
            Dbus.invokeShortcut("Overview");
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
    function copy(text) {
        Clipboard.copyText(text);
    }
}
