pragma Singleton

// What the launcher has been used to open, so that the second search for a
// thing is easier than the first.
//
// A count and a timestamp per result id, kept in the state directory. The
// arithmetic -- how a use decays, what it is worth -- is Rank's, which is
// pure and tested; this holds the numbers and writes them down.
//
// Two decisions worth keeping:
//
//   - It is keyed by a result id, not by a desktop entry, so a window, a
//     recent file or an action can be learned exactly as an application is.
//     The kind is part of the key ("app:org.kde.kate"), so a file and an
//     application of the same name cannot share a history.
//   - The file is pruned on write rather than on read. An entry decayed to
//     nothing is dead weight forever otherwise -- this is a file the shell
//     writes on every launch for the life of the install.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.system

QtObject {
    id: root

    // id -> { uses, lastMs }
    property var entries: ({})

    property bool loaded: false

    // Entries this many days untouched are dropped on the next write: past
    // three half-lives a use is worth a twelfth of a fresh one, which is less
    // than the rounding in Rank.recency.
    readonly property int forgetAfterDays: 90

    // Never let the file grow without bound, however much is opened. Well
    // above what anybody has installed.
    readonly property int maxEntries: 500

    function key(kind, id) {
        return `${kind ?? "app"}:${id ?? ""}`;
    }

    function historyFor(kind, id) {
        return root.entries[root.key(kind, id)] ?? null;
    }

    // Called when something is chosen, not when it is shown: a result that
    // was scrolled past has not been used.
    function record(kind, id) {
        if (!id)
            return;
        const k = root.key(kind, id);
        const prev = root.entries[k];
        root.entries = Object.assign({}, root.entries, {
            [k]: { uses: (prev?.uses ?? 0) + 1, lastMs: Date.now() }
        });
        root._persist();
        Log.debug("launcher", `used ${k} (${root.entries[k].uses}x)`);
    }

    // Offered in settings, because a history is the one thing here a person
    // may want gone without explanation.
    function forget() {
        root.entries = ({});
        root._persist();
        Log.info("launcher", "usage history cleared");
    }

    function _persist() {
        Fs.ensureDir(Paths.stateDir);
        root._view.setText(JSON.stringify({ version: 1, entries: root._pruned() }, null, 4) + "\n");
    }

    // Everything still worth keeping: recent enough, and within the cap --
    // the most recently used first, so the cap drops the stalest.
    function _pruned() {
        const cutoff = Date.now() - root.forgetAfterDays * 86400000;
        const kept = Object.keys(root.entries)
            .filter(k => (root.entries[k]?.lastMs ?? 0) >= cutoff)
            .sort((a, b) => (root.entries[b]?.lastMs ?? 0) - (root.entries[a]?.lastMs ?? 0))
            .slice(0, root.maxEntries);

        const out = {};
        for (const k of kept)
            out[k] = root.entries[k];
        return out;
    }

    readonly property FileView _view: FileView {
        path: Paths.launcherUsageFile
        atomicWrites: true
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.entries = data?.entries ?? {};
            } catch (e) {
                // A history that will not parse is not worth a warning on
                // every start: it is rebuilt by using the launcher.
                Log.debug("launcher", `usage history unreadable: ${e}`);
                root.entries = ({});
            }
            root.loaded = true;
        }

        // Nothing has been opened yet on this machine. Not a fault, and the
        // only signal that says so.
        onLoadFailed: {
            root.entries = ({});
            root.loaded = true;
        }
    }
}
