pragma Singleton

// The active Plasma colour scheme, read from kdeglobals and kept live.
//
// The shell reads KDE's theme rather than defining its own. That is the whole
// premise: the panel matches the rest of the desktop with no configuration,
// changing the colour scheme in System Settings restyles the panel
// immediately, and there is no second palette to keep in sync.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.system

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

    // Whether Plasma switches between a light and a dark global theme by
    // itself (System Settings > Global Theme; kded's lookandfeelautoswitcher
    // does it, on knighttimed's day and night). The shell does not need it to
    // follow -- the colour scheme changing is what it follows -- but the
    // settings page says which of the two is happening.
    property bool automaticLookAndFeel: false

    // All of kdeglobals, parsed: { group: { key: value } }. Empty until it
    // has been read, and again if it cannot be. Kept for the other things
    // that want a key of it -- the terminal KDE runs commands in, for one --
    // so the file is read once, on the debounce below, and not once more per
    // reader on every one of the watcher's four notifications.
    property var groups: ({})

    // Derived, so widgets never hand-roll an alpha.
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    readonly property color panelBackground: root.alpha(root.background, 0.85)
    readonly property color hoverBackground: root.alpha(root.foreground, 0.12)
    readonly property color pressedBackground: root.alpha(root.foreground, 0.2)

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
        path: `${Env.xdgConfigHome()}/kdeglobals`
        watchChanges: true
        printErrors: false

        // Debounced. KDE writes kdeglobals to a temporary file and renames it
        // over the original, which the watcher sees as several changes in a
        // few milliseconds -- four, measured here. Each one reparsed the file
        // and reassigned every colour in the shell, so one colour-scheme
        // change repainted everything four times.
        onFileChanged: settle.restart()

        // kdeglobals is an INI file, parsed here rather than shelled out to
        // kreadconfig6 once per key: that would be a dozen processes on the
        // startup path for one file.
        onLoaded: {
            const g = Ini.parse(text());
            root.groups = g;
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
            root.automaticLookAndFeel = (g["KDE"] ?? {}).AutomaticLookAndFeel === "true";

            root.loaded = true;
            Log.info("theme", "colour scheme loaded from kdeglobals");
        }

        onLoadFailed: {
            root.groups = ({});
            Log.warn("theme", "kdeglobals unreadable; using built-in colours");
        }
    }

    readonly property Timer _settle: Timer {
        id: settle
        interval: 120
        onTriggered: root._view.reload()
    }
}
