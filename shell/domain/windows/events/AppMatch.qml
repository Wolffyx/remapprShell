pragma Singleton

// Which installed application a window belongs to -- and so what it is called
// and what is drawn for it -- found the way KDE Plasma's own task manager
// finds it, so that a window is the same application here as in Plasma's
// panel.
//
// The order is libtaskmanager's, step for step: serviceFromMetadata,
// servicesFromEnvironment and servicesFromCmdLine in plasma-workspace's
// libtaskmanager/tasktools.cpp, and appDataFromService for the icon.
//
//   1. an entry's StartupWMClass, against the window's instance name and
//      then against its app id
//   2. the app id as the path of a desktop file
//   3. the app id as an entry's own name, its id
//   4. the app id as an entry's Name, among the entries a menu shows
//   5. the desktop file the process's environment names
//   6. the process's command line against the entries' Exec lines
//
// The first step that finds anything decides. Nothing here knows any program
// by name: every window goes through the same six.
//
// Pure, and in this module rather than beside WindowsService, so it is tested
// without a running shell (scripts/lint-tests.sh): the installed entries, the
// lookup by id and the icon theme are handed in. What a window says about its
// process -- steps 2, 5 and 6 -- comes from the window daemon, which can read
// /proc and files this cannot.

import QtQuick

QtObject {
    id: root

    // Interpreters whose command line names the program after them: the
    // program is the rest of the line. Plasma's list, in servicesFromCmdLine.
    readonly property var runtimes: ["perl"]

    // Plasma's app id for a window: the desktop file KWin associated with it,
    // else its resource class. It is what KWin hands Plasma's panel as the
    // window's app id, and what every step below that is not about the
    // process matches with.
    function appIdOf(window) {
        const file = String(window?.desktopFile ?? "");
        return file.length > 0 ? file : String(window?.appId ?? "");
    }

    // The lookups every window is matched through, built once per change of
    // the installed applications rather than searched per window per
    // repaint: each step is then a lookup by key, not a pass over every
    // entry.
    //
    // Several entries can share a key, and they are kept in id order. Plasma
    // takes them in the order its database lists them, which is no order in
    // particular; id order is at least the same on every run.
    function index(entries) {
        const out = {
            startupClass: new Map(),  // StartupWMClass, lower-cased
            name: new Map(),          // Name, lower-cased, of the entries a menu shows
            exec: new Map(),          // the Exec line, exactly as written
            id: new Map()             // the id, lower-cased
        };
        const add = (map, key, entry) => {
            if (key.length === 0)
                return;
            const list = map.get(key);
            if (list)
                list.push(entry);
            else
                map.set(key, [entry]);
        };
        const sorted = Array.from(entries ?? []).filter(e => !!e).sort((a, b) => {
            const x = String(a.id ?? ""), y = String(b.id ?? "");
            return x < y ? -1 : (x > y ? 1 : 0);
        });
        for (const entry of sorted) {
            add(out.startupClass, String(entry.startupClass ?? "").toLowerCase(), entry);
            if (!entry.noDisplay)
                add(out.name, String(entry.name ?? "").toLowerCase(), entry);
            add(out.exec, String(entry.execString ?? ""), entry);
            add(out.id, String(entry.id ?? "").toLowerCase(), entry);
        }
        return out;
    }

    // Plasma's way of choosing among several entries that fit
    // (sortServicesByMenuId): the first whose menu id begins with what was
    // looked for -- an entry named for it rather than one filed away in a
    // submenu -- and otherwise simply the first.
    function _pick(list, key) {
        if (!list || list.length === 0)
            return null;
        if (list.length === 1)
            return list[0];
        const k = key.toLowerCase();
        return list.find(e => `${e.id}.desktop`.toLowerCase().startsWith(k)) ?? list[0];
    }

    // What a match is, whichever step found it: the installed entry where
    // there is one -- only that can be pinned, started again or asked for its
    // actions -- a name and an icon, and the key windows of one application
    // are grouped by.
    function installed(entry, step) {
        const id = String(entry?.id ?? "");
        return {
            entry: entry,
            key: id,
            name: String(entry?.name ?? ""),
            icon: String(entry?.icon ?? ""),
            iconFile: "",
            step: step ?? ""
        };
    }

    // A desktop file the installed entries do not have, read by the daemon:
    // the one inside a mounted application, or one an app id names by path.
    // It can name and draw the window, but there is nothing to start again.
    function _fromFile(file, step) {
        return {
            entry: null,
            key: `file:${String(file.path ?? "")}`,
            name: String(file.name ?? ""),
            icon: String(file.icon ?? ""),
            // An icon beside the desktop file, which Plasma looks for only
            // for a file outside the installed ones -- where a mounted
            // application keeps its own.
            iconFile: String(file.iconFile ?? ""),
            step: step
        };
    }

    // The application `window` belongs to, or null when no step finds one.
    //
    // `index` is index(entries). `byId` finds an installed entry by its id
    // regardless of case, and sees the entries hidden from menus too, which
    // Plasma matches in every step but the fourth.
    function match(window, index, byId) {
        if (!window || !index)
            return null;
        const appId = root.appIdOf(window);
        const instance = String(window.resourceName ?? "");
        // With neither, Plasma does not look at all -- not even at the
        // process.
        if (appId.length === 0 && instance.length === 0)
            return null;

        if (appId.length > 0) {
            // 1. StartupWMClass is an entry saying outright which windows are
            // its own, so it is asked first -- about the instance name before
            // the app id, as Plasma asks.
            let found = instance.length > 0
                ? root._pick(index.startupClass.get(instance.toLowerCase()), instance) : null;
            if (!found)
                found = root._pick(index.startupClass.get(appId.toLowerCase()), appId);
            if (found)
                return root.installed(found, "startupClass");

            // 2. An app id that is a path: the desktop file at it, which the
            // daemon has read (`appIdFile`).
            if (appId.startsWith("/") && window.appIdFile)
                return root._fromFile(window.appIdFile, "path");

            // 3. The entry the app id names.
            const named = byId ? byId(appId) : null;
            if (named)
                return root.installed(named, "id");

            // 4. The app id as an entry's Name. A poor chance, since a Name is
            // translated and an app id is not, but Plasma takes it.
            found = root._pick(index.name.get(appId.toLowerCase()), appId);
            if (found)
                return root.installed(found, "name");
        }

        // 5. The desktop file the process's environment names. A path from
        // BAMF_DESKTOP_FILE_HINT counts only as the installed entry at that
        // path; the one in an APPDIR is taken as it is, since a mounted
        // application's entry is never installed.
        const hint = window.desktopHint;
        if (hint) {
            if (hint.variable === "APPDIR")
                return root._fromFile(hint, "environment");
            const hinted = hint.id && byId ? byId(hint.id) : null;
            if (hinted)
                return root.installed(hinted, "environment");
        }

        // 6. The command line.
        const line = String(window.cmdline ?? "");
        if (line.length === 0)
            return null;
        return root._byCommandLine(line, String(window.processName ?? ""),
                                   window.executables ?? [], window, index, 0);
    }

    // servicesFromCmdLine: the command line against the Exec lines -- whole,
    // then without the program's path, then without the arguments, then
    // without both -- and past an interpreter to the program it runs.
    function _byCommandLine(full, processName, executables, window, index, depth) {
        const exec = key => (index.exec.get(key) ?? [])[0] ?? null;
        const firstSpace = full.indexOf(" ");
        let cmdLine = full;
        let slash = 0;

        let found = exec(cmdLine);
        if (!found) {
            // Everything after the last slash before the first space: the
            // line with the program's directory taken off.
            slash = firstSpace >= 0 ? cmdLine.lastIndexOf("/", firstSpace) : cmdLine.lastIndexOf("/");
            if (slash > 0)
                found = exec(cmdLine.slice(slash + 1));
        }
        if (!found && firstSpace > 0) {
            cmdLine = cmdLine.slice(0, firstSpace);
            found = exec(cmdLine);
            if (!found) {
                slash = cmdLine.lastIndexOf("/");
                if (slash > 0)
                    found = exec(cmdLine.slice(slash + 1));
            }
        }
        if (found)
            return root.installed(found, "commandLine");

        const runtime = root.runtimes.includes(cmdLine)
            || (slash > 0 && root.runtimes.includes(cmdLine.slice(slash + 1)));
        if (runtime) {
            // Plasma looks again at what follows the interpreter, and at
            // nothing else. An interpreter alone on its line would have it
            // look at the same line for ever; that ends here instead.
            return firstSpace > 0 && depth < 8
                ? root._byCommandLine(full.slice(firstSpace + 1), processName, executables, window, index, depth + 1)
                : null;
        }

        // The last resort: no entry, but the command is a program the session
        // can run, and Plasma names the window after its process. There is
        // nothing to draw but the window's own icon, and the window groups as
        // one that matched nothing. Whether the command is a program is the
        // daemon's to say (`executables`), since it can look at the disk.
        if (processName.length > 0 && Array.from(executables).includes(cmdLine)) {
            return {
                entry: null,
                key: `class:${root.appIdOf(window)}`,
                name: processName,
                icon: "",
                iconFile: "",
                step: "process"
            };
        }
        return null;
    }

    // The key windows of one application are grouped by: the application's,
    // or the window's app id when nothing matched -- which is what Plasma
    // groups those by.
    function groupKey(app, window) {
        return app ? app.key : `class:${root.appIdOf(window)}`;
    }

    // What to draw for a window, as {name, file}: PanelIcon draws the file
    // when there is one, else the name from the icon theme, else the theme's
    // generic icon.
    //
    // appDataFromService's order: the application's icon from the theme,
    // then as a path, then as a file beside a desktop file read from disk;
    // and failing all of those, or with no application at all, the icon the
    // window carries -- the daemon's copy of it (`iconPath`). A window with
    // no icon of its own to copy, a Wayland-native one, is left to the theme
    // by its desktop file or class, as before.
    function icon(app, window, hasThemeIcon) {
        const fallback = WindowEvents.iconName(window);
        if (app) {
            const name = String(app.icon ?? "");
            if (name.length > 0 && hasThemeIcon && hasThemeIcon(name))
                return { name: name, file: "" };
            if (name.startsWith("/"))
                return { name: fallback, file: name };
            if (String(app.iconFile ?? "").length > 0)
                return { name: fallback, file: String(app.iconFile) };
        }
        const own = String(window?.iconPath ?? "");
        return { name: fallback, file: own };
    }

    // What to call it: the application's name, and for a window no
    // application matched, the window's own title (its class while it has
    // none). Plasma leaves such a window's application name empty and labels
    // a group of them with the app id; a title says more than a class that
    // is often a number.
    function name(app, window) {
        const named = String(app?.name ?? "");
        return named.length > 0 ? named : WindowEvents.label(window);
    }
}
