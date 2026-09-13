pragma Singleton

// What the keys do, read from kglobalshortcutsrc -- for the sheet the design
// opens with Meta+/. The keys shown are the ones actually bound on this
// machine, not a list of what they might be: a shortcut set to "none" is left
// out rather than advertised. Pure, and a module of its own so the tests can
// load it.
//
// A line is `Action=current,default,friendly name`. Several keys for one
// action are separated by a tab, which the file writes as the two characters
// "\t".

import QtQuick

QtObject {
    id: root

    // { "group": { "action": { keys: ["Meta+W"], label: "Toggle Overview" } } }
    function parse(text) {
        const out = {};
        let group = "";
        for (const raw of String(text ?? "").split("\n")) {
            const line = raw.trim();
            if (line.length === 0 || line.startsWith("#"))
                continue;
            if (line.startsWith("[")) {
                group = line.slice(1, -1);
                out[group] = out[group] ?? {};
                continue;
            }
            const eq = line.indexOf("=");
            if (eq < 0 || !group)
                continue;
            const action = line.slice(0, eq);
            const fields = line.slice(eq + 1).split(",");
            const current = (fields[0] ?? "").trim();
            const keys = current === "none" || current.length === 0 ? []
                : current.split("\\t").map(k => k.trim()).filter(k => k.length > 0 && k !== "none");
            out[group][action] = { keys: keys, label: fields.slice(2).join(",").trim() };
        }
        return out;
    }

    // The keys a group's action is bound to, or [].
    function keysOf(map, group, action) {
        return map?.[group]?.[action]?.keys ?? [];
    }

    // The sheet: what is worth a line, in the order a person looks for it,
    // each with the keys actually bound. A line with no keys is left out, and
    // so is a section left empty.
    readonly property var wanted: [
        { title: "Shell", rows: [
            ["plasmashell", "activate application launcher", "Application menu"],
            ["services][org.kde.krunner.desktop", "_launch", "Search"],
            ["kwin", "Overview", "Overview"],
            ["kwin", "Grid View", "Virtual desktops"],
            ["kwin", "Show Desktop", "Show the desktop"],
            ["ksmserver", "Lock Session", "Lock"],
            ["ksmserver", "Log Out", "Log out"],
            ["services][org.kde.spectacle.desktop", "RectangularRegionScreenShot", "Screenshot of a region"],
            ["kwin", "Toggle Night Color", "Night Light"]
        ] },
        { title: "Windows and desktops", rows: [
            ["kwin", "Walk Through Windows", "Switch windows"],
            ["kwin", "Window Close", "Close the window"],
            ["kwin", "Window Maximize", "Maximise"],
            ["kwin", "Window Minimize", "Minimise"],
            ["kwin", "Window Fullscreen", "Full screen"],
            ["kwin", "Window Quick Tile Left", "Tile to the left"],
            ["kwin", "Window Quick Tile Right", "Tile to the right"],
            ["kwin", "Switch to Desktop 1", "Desktop 1"],
            ["kwin", "Window to Desktop 1", "Window to desktop 1"],
            ["kwin", "Window to Next Screen", "Window to the next screen"],
            ["kwin", "Kill Window", "Kill a window"]
        ] }
    ]

    // The shell's own keys. They are this project's kglobalaccel component --
    // one group named after the slug, an action per binding -- because only a
    // component with a running owner ever gets the key; see
    // scripts/shortcuts.sh. The desktop-file form is still read so a shortcut
    // set before the move still appears on the sheet.
    function shellRows(map, slug) {
        const rows = [];
        const own = map?.[slug] ?? {};
        for (const action of Object.keys(own)) {
            const keys = root.keysOf(map, slug, action);
            if (keys.length > 0)
                rows.push({ keys: keys, label: own[action].label || action });
        }
        for (const group of Object.keys(map ?? {})) {
            const m = new RegExp(`^services\\]\\[${slug}-([a-z]+)\\.desktop$`).exec(group);
            if (!m)
                continue;
            const keys = root.keysOf(map, group, "_launch");
            if (keys.length > 0)
                rows.push({ keys: keys, label: map[group]._launch.label || m[1] });
        }
        return rows;
    }

    function sections(map, slug) {
        const out = [];
        for (const section of root.wanted) {
            const rows = [];
            for (const [group, action, label] of section.rows) {
                const keys = root.keysOf(map, group, action);
                if (keys.length > 0)
                    rows.push({ keys: keys, label: label });
            }
            if (section.title === "Shell")
                rows.push(...root.shellRows(map, slug));
            if (rows.length > 0)
                out.push({ title: section.title, rows: rows });
        }
        return out;
    }
}
