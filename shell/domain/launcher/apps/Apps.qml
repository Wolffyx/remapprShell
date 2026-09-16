pragma Singleton

// How the start menu arranges applications and files: the categories down
// its rail, the pinned apps when none have been chosen, the A-Z list, and the
// recent files. Pure, and a module of its own so the tests can load it.
//
// An application here is anything with `id`, `name` and `categories` -- a
// Quickshell DesktopEntry, or a plain object in a test.

import QtQuick

QtObject {
    id: root

    // Down the two-pane menu's rail, as the design has them.
    readonly property var categories: [
        { id: "all", glyph: "apps", label: "All apps" },
        { id: "internet", glyph: "language", label: "Internet" },
        { id: "development", glyph: "code", label: "Development" },
        { id: "multimedia", glyph: "movie", label: "Multimedia" },
        { id: "games", glyph: "sports_esports", label: "Games" },
        { id: "utilities", glyph: "folder", label: "Utilities and office" },
        { id: "system", glyph: "settings_applications", label: "System" }
    ]

    function _cats(app) {
        // A QML list is not a JS array; String() joins it with commas.
        return String(app?.categories ?? "").split(/[;,]/).map(c => c.trim()).filter(c => c.length > 0);
    }

    // The one rail category an application's freedesktop categories put it
    // in. The first that applies wins: a game that is also a utility is a
    // game.
    function categoryOf(app) {
        const c = root._cats(app);
        const has = k => c.indexOf(k) >= 0;
        if (has("Game"))
            return "games";
        if (has("Development") || has("IDE"))
            return "development";
        if (has("Network") || has("WebBrowser") || has("Email") || has("Chat") || has("InstantMessaging"))
            return "internet";
        if (has("AudioVideo") || has("Audio") || has("Video") || has("Graphics") || has("Photography"))
            return "multimedia";
        if (has("Settings") || has("System") || has("Monitor") || has("PackageManager"))
            return "system";
        return "utilities";
    }

    function inCategory(apps, category) {
        if (category === "all")
            return root.sorted(apps);
        return root.sorted((apps ?? []).filter(a => root.categoryOf(a) === category));
    }

    function sorted(apps) {
        return (apps ?? []).slice().sort((a, b) => String(a.name).localeCompare(String(b.name)));
    }

    // Pinned ids to applications, in the order pinned. An id may carry
    // ".desktop" or not; one no longer installed is left out.
    function resolvePinned(apps, ids) {
        const byId = {};
        for (const a of apps ?? [])
            byId[String(a.id).replace(/\.desktop$/, "")] = a;
        return (ids ?? []).map(id => byId[String(id).replace(/\.desktop$/, "")]).filter(a => !!a);
    }

    // With nothing pinned, one application for each thing most people open
    // every day, where one is installed: a terminal, files, a browser, an
    // editor, music, photos, a calculator, mail, packages, settings.
    readonly property var everyday: [
        ["TerminalEmulator"], ["FileManager"], ["WebBrowser"], ["TextEditor"],
        ["Music", "Audio", "Player"], ["Viewer", "Photography"], ["Calculator"],
        ["Email"], ["PackageManager"], ["Settings", "DesktopSettings"]
    ]

    function pickPinned(apps, count) {
        const list = root.sorted(apps);
        const chosen = [];
        for (const wanted of root.everyday) {
            const app = list.find(a => chosen.indexOf(a) < 0 && wanted.some(w => root._cats(a).indexOf(w) >= 0));
            if (app)
                chosen.push(app);
            if (chosen.length >= (count ?? 10))
                break;
        }
        return chosen;
    }

    // [{ letter, apps }], A to Z, anything not starting with a letter under
    // "#" at the end.
    function byLetter(apps) {
        const groups = [];
        const index = {};
        for (const a of root.sorted(apps)) {
            const first = String(a.name ?? "").trim().charAt(0).toUpperCase();
            const letter = /[A-Z]/.test(first) ? first : "#";
            if (index[letter] === undefined) {
                index[letter] = groups.length;
                groups.push({ letter: letter, apps: [] });
            }
            groups[index[letter]].apps.push(a);
        }
        return groups.sort((x, y) => x.letter === "#" ? 1 : y.letter === "#" ? -1 : x.letter.localeCompare(y.letter));
    }

    // The files in a recently-used.xbel, most recently used first: { uri,
    // name, dir, folder, when }. Only local files; web addresses and the
    // like are left out. `home` is shown as "~".
    function parseRecent(xml, home, limit) {
        const out = [];
        const text = String(xml ?? "");
        const re = /<bookmark\b([^>]*)>([\s\S]*?)<\/bookmark>/g;
        let m;
        while ((m = re.exec(text)) !== null) {
            const attr = name => (new RegExp(`\\b${name}="([^"]*)"`).exec(m[1]) ?? [])[1] ?? "";
            const href = attr("href");
            if (!href.startsWith("file://"))
                continue;
            let path;
            try {
                path = decodeURIComponent(href.slice(7));
            } catch (e) {
                continue;
            }
            const when = Math.max(Date.parse(attr("modified")) || 0, Date.parse(attr("visited")) || 0);
            const mime = (/mime-type\s+type="([^"]*)"/.exec(m[2]) ?? [])[1] ?? "";
            const slash = path.lastIndexOf("/");
            let dir = path.slice(0, Math.max(0, slash)) || "/";
            if (home && (dir === home || dir.startsWith(home + "/")))
                dir = "~" + dir.slice(home.length);
            out.push({ uri: href, path: path, name: path.slice(slash + 1), dir: dir,
                       folder: mime === "inode/directory", when: when });
        }
        return out.sort((a, b) => b.when - a.when).slice(0, limit ?? 10);
    }

    // ---- what the system opens things with ----------------------------------

    // The value of one key in one group of an INI-shaped file, or "".
    //
    // Small and forgiving on purpose: this is asked of KDE's own files, which
    // are written by KDE and read here only to learn what is already true.
    function iniValue(text, group, key) {
        let inGroup = false;
        for (const raw of String(text ?? "").split("\n")) {
            const line = raw.trim();
            if (line.startsWith("[")) {
                inGroup = line === `[${group}]`;
                continue;
            }
            if (!inGroup)
                continue;
            const eq = line.indexOf("=");
            if (eq > 0 && line.slice(0, eq).trim() === key)
                return line.slice(eq + 1).trim();
        }
        return "";
    }

    // The desktop ids named as the default for something in a mimeapps.list:
    // the browser that opens links, the viewer that opens images, and so on.
    //
    // Only the first id of each line: the rest are the fallbacks, and a
    // fallback is not what the system opens that kind of thing with. Added
    // Associations are skipped for the same reason -- a thing that *can* open
    // PDFs is not the thing that does.
    //
    // Ids come back without the ".desktop", which is how a desktop entry
    // names itself everywhere else in this shell.
    function parseDefaultApps(text) {
        const out = [];
        let inDefaults = false;
        for (const raw of String(text ?? "").split("\n")) {
            const line = raw.trim();
            if (line.startsWith("[")) {
                inDefaults = line === "[Default Applications]";
                continue;
            }
            if (!inDefaults || line.startsWith("#"))
                continue;
            const eq = line.indexOf("=");
            if (eq <= 0)
                continue;
            const first = line.slice(eq + 1).split(";")[0].trim();
            if (first.length === 0)
                continue;
            const id = first.endsWith(".desktop") ? first.slice(0, -8) : first;
            if (out.indexOf(id) < 0)
                out.push(id);
        }
        return out;
    }

    // What `xdg-mime query default` answered, one type per line, in the order
    // the types were asked about.
    //
    // A line can be empty (nothing is the default for that type), and it can
    // carry more than one entry; the first is the default and the rest are
    // fallbacks, exactly as in mimeapps.list.
    function parseQueriedDefaults(text) {
        const out = [];
        for (const raw of String(text ?? "").split("\n")) {
            const first = raw.split(";")[0].trim();
            if (first.length === 0)
                continue;
            const id = first.endsWith(".desktop") ? first.slice(0, -8) : first;
            if (out.indexOf(id) < 0)
                out.push(id);
        }
        return out;
    }
}
