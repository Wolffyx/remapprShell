pragma Singleton

// Notices that the shell has crashed, because nothing else will.
//
// Quickshell catches a fatal signal itself: it writes a dump under
// ~/.cache/quickshell/crashes/, then restarts the shell in process. systemd
// never sees a failure -- the unit stays active, NRestarts stays at 0 -- so
// the `OnFailure=` reporter this project built for exactly this moment does
// not run. Five real crashes produced five dumps and no report, and were found
// only because someone opened the directory.
//
// That restart is also what makes this work: the config is loaded again, so
// this runs again, and a dump written moments ago is still sitting there.
//
// What it does is write a report and say so in the journal. It does not send
// anything and it does not put a window on screen: a shell that has just come
// back should not open a dialog over whatever the user was doing. `rmpr ask
// --crash` is how a person acts on it, and `rmpr doctor` says it is there.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.system

QtObject {
    id: root

    // When the newest dump already accounted for was written. Time rather than
    // identity: an id does not survive its dump being deleted, and "the newest
    // is not the one I recorded" is then true of a dump OLDER than it -- which
    // reports an old crash as a new one. Seen the first time this was wired up.
    //
    // The comparison itself belongs to the CLI (`crash since`), where a test
    // can reach it. This part starts it and reacts.
    property int lastSeen: 0
    property string reported: ""

    function check() {
        sinceProc.running = false;
        sinceProc.command = [Branding.ctlBin, "crash", "since", String(root.lastSeen)];
        sinceProc.running = true;
    }

    readonly property Process _since: Process {
        id: sinceProc
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                if (line.length === 0)
                    return;   // nothing newer: an ordinary start

                const parts = line.split(/\s+/);
                const when = parseInt(parts[0], 10);
                const id = parts[1] ?? "";
                if (!Number.isFinite(when) || id.length === 0)
                    return;

                root._remember(when, id);

                // A first start records what is already there without
                // reporting it: every dump on a machine that has never run
                // this predates it, and none of them is news.
                if (root._seeding) {
                    root._seeding = false;
                    Log.debug("crash", `${id} predates this shell; noted, not reported`);
                    return;
                }

                root._report(id);
            }
        }
    }

    property bool _seeding: false

    function _report(id) {
        root.reported = id;
        Log.warn("crash", `the shell crashed and restarted itself (${id}); writing a report`);
        reportProc.running = false;
        reportProc.command = [Branding.ctlBin, "report", "create",
                              "--reason", `crash ${id}`, "--crash", id];
        reportProc.running = true;
    }

    // Written locally and sent nowhere, like every report. It is deliberately
    // not put on screen: a shell that has just come back should not open a
    // window over whatever the user was doing. The journal says it happened,
    // `doctor` says it is there, and `ask --crash` is how a person acts on it.
    readonly property Process _reporter: Process {
        id: reportProc
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = text.trim().split("\n").pop();
                if (dir.length > 0)
                    Log.warn("crash", `report written: ${dir} -- read it with 'report show', ask about it with 'ask --crash'`);
            }
        }
    }

    function _remember(when, id) {
        root.lastSeen = when;
        Fs.ensureDir(Paths.stateDir);
        seenView.setText(`${when} ${id}\n`);
    }

    // Which crash has been accounted for, kept across restarts. In state
    // rather than config: it is ours to remember, never something a person
    // would set.
    readonly property FileView _seen: FileView {
        id: seenView
        path: Paths.lastCrashFile
        atomicWrites: true
        printErrors: false

        onLoaded: {
            const when = parseInt(seenView.text().trim().split(/\s+/)[0], 10);
            root.lastSeen = Number.isFinite(when) ? when : 0;
            root.check();
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.lastSeen = 0;
                root._seeding = true;
                root.check();
            }
        }
    }
}
