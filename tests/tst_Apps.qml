// Tests for how the start menu arranges applications and files.

import QtQuick
import QtTest
import qs.domain.launcher.apps

TestCase {
    name: "Apps"

    function app(id, name, cats) {
        return { id: id, name: name, categories: cats };
    }

    readonly property var apps: [
        app("org.kde.konsole", "Konsole", ["System", "TerminalEmulator"]),
        app("org.kde.dolphin", "Dolphin", ["Qt", "KDE", "System", "FileTools", "FileManager"]),
        app("firefox", "Firefox", ["Network", "WebBrowser"]),
        app("org.kde.kate", "Kate", ["Qt", "KDE", "Utility", "TextEditor"]),
        app("steam", "Steam", ["Network", "FileTransfer", "Game"]),
        app("code", "Visual Studio Code", ["Utility", "TextEditor", "Development", "IDE"]),
        app("org.kde.elisa", "Elisa", ["Qt", "KDE", "AudioVideo", "Audio", "Player", "Music"]),
        app("systemsettings", "System Settings", ["Qt", "KDE", "Settings"]),
        app("7zip", "7-Zip", ["Utility", "Archiving"])
    ]

    function test_categories() {
        compare(Apps.categoryOf(apps[4]), "games");        // a game first, whatever else
        compare(Apps.categoryOf(apps[5]), "development");
        compare(Apps.categoryOf(apps[2]), "internet");
        compare(Apps.categoryOf(apps[6]), "multimedia");
        compare(Apps.categoryOf(apps[7]), "system");
        compare(Apps.categoryOf(apps[3]), "utilities");
        compare(Apps.categoryOf(app("x", "X", "")), "utilities");
    }

    // A QML list arrives comma-joined; both are read.
    function test_categories_as_a_string() {
        compare(Apps.categoryOf(app("s", "S", "Network,FileTransfer,Game")), "games");
    }

    function test_in_category_sorted() {
        const dev = Apps.inCategory(apps, "development");
        compare(dev.length, 1);
        compare(Apps.inCategory(apps, "all")[0].name, "7-Zip");
    }

    function test_pinned_in_order_and_missing_left_out() {
        const p = Apps.resolvePinned(apps, ["firefox", "gone.desktop", "org.kde.kate.desktop"]);
        compare(p.map(a => a.id), ["firefox", "org.kde.kate"]);
    }

    function test_everyday_picks() {
        const p = Apps.pickPinned(apps, 10).map(a => a.id);
        compare(p[0], "org.kde.konsole");
        compare(p[1], "org.kde.dolphin");
        compare(p[2], "firefox");
        verify(p.indexOf("org.kde.elisa") >= 0);
        verify(p.indexOf("systemsettings") >= 0);
        compare(new Set(p).size, p.length);
        compare(Apps.pickPinned(apps, 2).length, 2);
    }

    function test_by_letter() {
        const g = Apps.byLetter(apps);
        compare(g[0].letter, "D");
        compare(g[g.length - 1].letter, "#");
        compare(g[g.length - 1].apps[0].name, "7-Zip");
        const k = g.find(x => x.letter === "K");
        compare(k.apps.map(a => a.name), ["Kate", "Konsole"]);
    }

    readonly property string xbel: `<?xml version="1.0"?>
<xbel>
  <bookmark added="2025-10-25T15:31:07Z" href="file:///home/me/Pictures/Wallpapers" modified="2026-08-27T18:00:28Z" visited="2026-08-27T18:00:28Z">
    <info><metadata owner="http://freedesktop.org"><mime:mime-type type="inode/directory"/></metadata></info>
  </bookmark>
  <bookmark href="https://example.org/" added="2026-06-08T15:02:25Z" modified="2026-09-10T20:59:06Z" visited="2026-09-10T20:59:06Z">
    <info><metadata owner="http://freedesktop.org"><mime:mime-type type="text/html"/></metadata></info>
  </bookmark>
  <bookmark visited="2026-09-11T10:00:00Z" href="file:///home/me/.config/remappr/shell%20copy.json" added="2026-09-01T10:00:00Z" modified="2026-09-01T10:00:00Z">
    <info><metadata owner="http://freedesktop.org"><mime:mime-type type="application/json"/></metadata></info>
  </bookmark>
  <bookmark href="file:///etc/hosts" added="2026-01-01T00:00:00Z" modified="2026-01-01T00:00:00Z" visited="2026-01-01T00:00:00Z">
  </bookmark>
</xbel>`

    function test_recent_files_newest_first_local_only() {
        const r = Apps.parseRecent(xbel, "/home/me", 10);
        compare(r.length, 3);
        compare(r[0].name, "shell copy.json");     // visited last, decoded
        compare(r[0].dir, "~/.config/remappr");
        compare(r[1].name, "Wallpapers");
        verify(r[1].folder);
        compare(r[1].dir, "~/Pictures");
        compare(r[2].dir, "/etc");
        compare(Apps.parseRecent(xbel, "/home/me", 1).length, 1);
    }

    // ---- what the system opens things with ---------------------------------

    function test_what_xdg_mime_answered() {
        // One line per type asked about, in order; a type nothing handles
        // answers with an empty line, and a type with fallbacks answers with
        // the default first.
        const answers = `google-chrome.desktop

org.kde.gwenview.desktop
org.kde.okular.desktop;org.kde.gwenview.desktop;

google-chrome.desktop
`
        const ids = Apps.parseQueriedDefaults(answers);
        compare(ids.join(","), "google-chrome,org.kde.gwenview,org.kde.okular");
        compare(Apps.parseQueriedDefaults("").length, 0);
        compare(Apps.parseQueriedDefaults(undefined).length, 0);
    }
}
