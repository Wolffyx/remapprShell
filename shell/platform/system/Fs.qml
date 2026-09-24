pragma Singleton

// Filesystem operations the QML API does not provide.
//
// Quickshell's FileView reads and writes files but cannot create directories,
// and it does not report a file being *created* -- watchChanges only tracks a
// path that already exists. Both gaps are filled here rather than in the
// callers, so the layer above stays free of process plumbing.

import QtQuick
import Quickshell
import qs.core

QtObject {
    id: root

    // Creates a directory and its parents. Fire-and-forget: callers write
    // through FileView immediately afterwards, and a failure surfaces there as
    // a save error with a real path in it.
    //
    // Once per directory per session. Every save asks first, and some save
    // often: the quarantine ledger once per third-party widget as the panel
    // is built, the launcher's history once per launch. Each ask was a mkdir
    // process for a directory made the first time.
    function ensureDir(path) {
        if (!path || root._made[path])
            return;
        root._made[path] = true;
        Quickshell.execDetached(["mkdir", "-p", path]);
        Log.debug("fs", `ensureDir ${path}`);
    }

    // For a save that failed: the directory it went to may be gone -- a
    // restore point replaces the whole state directory -- so the next
    // ensureDir makes it again instead of trusting the first.
    function forget(path) {
        delete root._made[path];
    }

    // path -> true for every directory made this session. Nothing binds to
    // it, so it is changed in place.
    property var _made: ({})
}
