pragma ComponentBehavior: Bound

// Loads the per-output overrides for one screen.
//
// One of these exists per connected output, created by the loader below, so
// plugging a monitor in picks up its overrides without a restart and
// unplugging one stops watching a file nothing reads.

import QtQuick
import Quickshell.Io
import qs.core

QtObject {
    id: root

    required property string screenName

    readonly property FileView _view: FileView {
        path: Paths.monitorConfigFile(ConfigStore.profile, root.screenName)
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            try {
                const data = JSON.parse(text());
                ConfigStore.monitorData = Object.assign({}, ConfigStore.monitorData,
                                                        { [root.screenName]: data });
                Log.info("config", `overrides for ${root.screenName} loaded`);
            } catch (e) {
                Log.error("config", `overrides for ${root.screenName} are invalid: ${e}`);
            }
        }

        onLoadFailed: {
            // No overrides for this output is the normal case.
            const next = Object.assign({}, ConfigStore.monitorData);
            delete next[root.screenName];
            ConfigStore.monitorData = next;
        }
    }
}
