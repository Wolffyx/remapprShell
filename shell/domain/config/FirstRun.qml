pragma Singleton

// Whether this machine has ever been set up, and the marker that says so.
//
// "The wizard has never run here" used to be one question with one answer: a
// marker file in the state directory. On 2026-09-14 that answer was wrong in
// the most expensive way available. A restore point rolled the state directory
// back past the day the marker was written; the shell read its absence as a
// first run; the wizard appeared over a desktop somebody had been using all
// week, and its Finish wrote a fresh profile over a configuration built up
// across days.
//
// So it is two questions now. The marker says whether the wizard has finished
// here. The configuration says whether anybody has ever set anything. Only a
// machine where both say no is a first run; a configured machine that has lost
// its marker has the marker written back instead, quietly, because there is
// nothing to ask somebody who has already answered.
//
// The other direction is deliberately left alone. A marker with an empty
// profile behind it is an ordinary thing to have -- somebody skipped the
// wizard, or took the defaults at every step -- and showing it again would
// make the skip button a lie.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.system

QtObject {
    id: root

    // True once, when this really is a machine nobody has set up. Whatever
    // shows the wizard watches this; nothing else writes it.
    property bool wanted: false

    // Set as soon as the question has an answer, so a later change of mind --
    // the profile loading, the marker arriving -- cannot ask it twice.
    property bool decided: false

    // What the marker file said, once it has been looked for.
    property bool markerSeen: false
    property bool markerChecked: false

    // Writes the marker. Called when the wizard finishes or is skipped, and by
    // the decision below when it finds a configured machine with no marker.
    function markDone() {
        Fs.ensureDir(Paths.stateDir);
        doneView.setText(`${Branding.version}\n`);
        root.markerSeen = true;
    }

    // Both answers are read asynchronously, so this runs whenever either
    // arrives and does nothing until both are in.
    function _decide() {
        if (root.decided || !root.markerChecked || !ConfigStore.profileLoaded)
            return;

        if (root.markerSeen) {
            root.decided = true;
            return;
        }

        if (ConfigStore.configured) {
            root.decided = true;
            Log.info("wizard", "no marker, but this configuration has settings in it: "
                             + "not a first run. Writing the marker instead of asking again");
            root.markDone();
            return;
        }

        root.decided = true;
        Log.info("wizard", "first run; showing the wizard");
        root.wanted = true;
    }

    readonly property Connections _config: Connections {
        target: ConfigStore
        function onProfileLoadedChanged(): void { root._decide(); }
    }

    readonly property FileView _done: FileView {
        id: doneView
        path: Paths.wizardDoneFile
        atomicWrites: true
        printErrors: false

        onSaveFailed: Fs.forget(Paths.stateDir)

        onLoaded: {
            root.markerSeen = true;
            root.markerChecked = true;
            root._decide();
        }

        onLoadFailed: err => {
            // Anything other than "it is not there" is a machine we cannot
            // read the marker on -- a permission problem, a directory where a
            // file should be. Treated as seen: guessing wrong towards "first
            // run" is the expensive direction, and this is exactly the case
            // where guessing is all that is left.
            if (err !== FileViewError.FileNotFound)
                root.markerSeen = true;
            root.markerChecked = true;
            root._decide();
        }
    }
}
