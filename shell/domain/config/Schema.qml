pragma Singleton

// The settings schema: what every setting is, so the GUI can render it.
//
// Kept separate from the defaults file. Defaults answer "what value", the
// schema answers "what kind of thing, called what, explained how" -- and a GUI
// needs both. Generating one from the other would mean either labels in the
// defaults or values in the schema, and both age badly.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

QtObject {
    id: root

    property var sections: []
    property bool loaded: false

    function section(id) {
        return root.sections.find(s => s.id === id) ?? null;
    }

    readonly property FileView _view: FileView {
        path: `${Branding.dataDir}/config/schema/shell.json`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            try {
                root.sections = JSON.parse(text()).sections ?? [];
                root.loaded = true;
                Log.info("config", `schema loaded (${root.sections.length} sections)`);
            } catch (e) {
                Log.error("config", `settings schema is invalid: ${e}`);
            }
        }

        onLoadFailed: Log.error("config", `settings schema missing at ${path}`)
    }
}
