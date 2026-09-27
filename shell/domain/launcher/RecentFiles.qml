pragma Singleton

// The files used most recently, as KDE and GTK applications both record them
// in recently-used.xbel -- what the start menu shows under "Recent". Read,
// never written, and followed as it changes.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.platform.system
import qs.domain.launcher.apps

QtObject {
    id: root

    property var files: []

    // With whatever opens it, in a scope of its own: see Launch.
    function open(file) {
        if (file?.uri)
            Launch.open(file.uri);
    }

    readonly property FileView _view: FileView {
        path: `${Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")}/recently-used.xbel`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.files = Apps.parseRecent(text(), Quickshell.env("HOME") ?? "", 12)
    }
}
