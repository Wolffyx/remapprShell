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
    function ensureDir(path) {
        if (!path)
            return;
        Quickshell.execDetached(["mkdir", "-p", path]);
        Log.debug("fs", `ensureDir ${path}`);
    }
}
