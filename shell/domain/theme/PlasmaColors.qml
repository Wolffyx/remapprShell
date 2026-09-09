pragma Singleton

// The active Plasma colour scheme, read from kdeglobals and kept live.
//
// The shell reads KDE's theme rather than defining its own. That is the whole
// premise: the panel matches the rest of the desktop with no configuration,
// changing the colour scheme in System Settings restyles the panel
// immediately, and there is no second palette to keep in sync.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

QtObject {
    id: root

    // Fallbacks are a readable dark scheme, used only until kdeglobals has been
    // read -- or if it cannot be, which should never take the panel down.
    property color background: "#191920"
    property color backgroundAlternate: "#25252e"
    property color foreground: "#acaab5"
    property color foregroundInactive: "#76747f"
    property color accent: "#c2c0eb"
    property color negative: "#FF6A9D"
    property color neutral: "#FF734A"
    property color positive: "#31C193"
    property color selectionBackground: "#5a5a7a"
    property color selectionForeground: "#ffffff"

    property bool loaded: false

    // Derived, so widgets never hand-roll an alpha.
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    readonly property color panelBackground: root.alpha(root.background, 0.85)
    readonly property color hoverBackground: root.alpha(root.foreground, 0.12)
    readonly property color pressedBackground: root.alpha(root.foreground, 0.2)

    // kdeglobals is an INI file with [Group] headers and Key=Value lines.
    // Parsed here rather than shelled out to kreadconfig6 once per key: that
    // would be a dozen processes on the startup path for one file.
    function _parse(text) {
        const groups = {};
        let current = "";
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (line.length === 0 || line.startsWith("#"))
                continue;
            if (line.startsWith("[")) {
                current = line.replace(/^\[|\]$/g, "");
                groups[current] = groups[current] ?? {};
                continue;
            }
            const eq = line.indexOf("=");
            if (eq < 0 || current === "")
                continue;
            groups[current][line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
        }
        return groups;
    }

    // KDE writes colours as "r,g,b" triples in kdeglobals, but colour schemes
    // installed as .colors files may use #rrggbb. Both are accepted.
    function _colour(raw, fallback) {
        if (!raw)
            return fallback;
        if (raw.startsWith("#"))
            return raw;
        const parts = raw.split(",").map(s => parseInt(s.trim(), 10));
        if (parts.length >= 3 && parts.every(Number.isFinite))
            return Qt.rgba(parts[0] / 255, parts[1] / 255, parts[2] / 255, 1);
        return fallback;
    }

    readonly property FileView _view: FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")}/kdeglobals`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            const g = root._parse(text());
            const win = g["Colors:Window"] ?? {};
            const sel = g["Colors:Selection"] ?? {};

            root.background = root._colour(win.BackgroundNormal, root.background);
            root.backgroundAlternate = root._colour(win.BackgroundAlternate, root.backgroundAlternate);
            root.foreground = root._colour(win.ForegroundNormal, root.foreground);
            root.foregroundInactive = root._colour(win.ForegroundInactive, root.foregroundInactive);
            root.accent = root._colour(win.DecorationFocus, root.accent);
            root.negative = root._colour(win.ForegroundNegative, root.negative);
            root.neutral = root._colour(win.ForegroundNeutral, root.neutral);
            root.positive = root._colour(win.ForegroundPositive, root.positive);
            root.selectionBackground = root._colour(sel.BackgroundNormal, root.selectionBackground);
            root.selectionForeground = root._colour(sel.ForegroundNormal, root.selectionForeground);

            root.loaded = true;
            Log.info("theme", "colour scheme loaded from kdeglobals");
        }

        onLoadFailed: Log.warn("theme", "kdeglobals unreadable; using built-in colours")
    }
}
