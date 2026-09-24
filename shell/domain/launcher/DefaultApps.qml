pragma Singleton

// What this system opens things with: the browser that gets a link, the
// terminal KDE runs a command in, the viewer that gets an image.
//
// Read, never written. The parsing is Apps', which is pure and tested; this
// holds the file open and follows it, because a default changed in System
// Settings should reach the search without a restart.
//
// Reading mimeapps.list is not enough, and believing it was is what made the
// first version do nothing on the machine it was written for. System
// Settings shows Gwenview, Haruna, Kate, Dolphin and Konsole as the defaults
// there while the user's mimeapps.list names none of them: most defaults are
// derived -- from the packages' own mimeapps.list files, the mimeinfo caches
// and the desktop files' MimeType lines -- and resolving them is exactly what
// `xdg-mime query default` does. So the file is followed for *when* to ask,
// and xdg-mime is asked for *what the answer is*.
//
// Why the search cares: "the first terminal in the list should be the one
// this machine actually uses". Before anybody has opened anything -- a fresh
// install, where there is no history to learn from -- this is the only thing
// that knows which of eight terminals is the right one.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.domain.launcher.apps
import qs.domain.theme

QtObject {
    id: root

    // Desktop ids, without the ".desktop".
    property var ids: []

    // The kinds of thing worth knowing the default for: the ones System
    // Settings itself offers, which is the same list a person would think of
    // as "my default applications". Asked once at startup and again whenever
    // the associations change, never per keystroke.
    readonly property var types: [
        "x-scheme-handler/http",          // web browser
        "x-scheme-handler/mailto",        // email
        "text/calendar",                  // calendar
        "x-scheme-handler/tel",           // phone numbers
        "image/png",                      // image viewer
        "audio/mpeg",                     // music
        "video/mp4",                      // video
        "text/plain",                     // text editor
        "application/pdf",                // PDF
        "inode/directory",                // file manager
        "x-scheme-handler/terminal",      // terminal emulator
        "application/zip",                // archives
        "x-scheme-handler/geo"            // maps
    ]

    // The terminal is not a MIME type, so it is not in mimeapps.list at all:
    // KDE keeps it in kdeglobals, as the command rather than the entry id.
    //
    // Read from PlasmaColors, which already follows kdeglobals -- debounced,
    // where a watcher of this file's own saw each colour-scheme change as
    // four and read the whole file four times. The value is a command line
    // ("konsole", "alacritty -e"); the first word of it is the binary, which
    // is what a desktop id is built from.
    readonly property string terminal:
        String(PlasmaColors.groups.General?.TerminalApplication ?? "").split(/\s+/)[0] ?? ""

    function isDefault(id) {
        const wanted = String(id ?? "");
        if (wanted.length === 0)
            return false;
        if (root.ids.indexOf(wanted) >= 0)
            return true;
        // The terminal, matched on the command: "konsole", "alacritty".
        return root.terminal.length > 0 && root.terminal === wanted.split(".").pop();
    }

    readonly property string _configHome:
        Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`

    readonly property FileView _mimeapps: FileView {
        path: `${root._configHome}/mimeapps.list`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        // The file is the signal, not the answer: xdg-mime is asked again
        // whenever it changes.
        onLoaded: root._ask()
        onLoadFailed: root._ask()
    }

    function _ask() {
        root._query.running = false;
        root._query.running = true;
    }

    readonly property Process _query: Process {
        running: true
        // One process for the lot: thirteen of them at startup, one per type,
        // is thirteen processes to learn something that changes once a year.
        command: ["sh", "-c", `for t in ${root.types.join(" ")}; do xdg-mime query default "$t"; echo; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ids = Apps.parseQueriedDefaults(text);
                Log.debug("launcher", `defaults: ${root.ids.join(", ") || "none"}`);
            }
        }
    }
}
