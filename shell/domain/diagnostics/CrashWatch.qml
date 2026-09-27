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
//
// The deciding is all in `rmpr crash check` -- which dumps are ours, whether
// one is newer than the last accounted for, and remembering that it now is.
// This runs it and reacts. That is deliberate: the first version kept the
// record here in QML and got two things wrong that a test would have caught
// at once. It compared by id, so deleting the recorded dump made an older one
// look new; and on a machine with no dumps at all it wrote no record, so the
// very first crash was seeded away as history instead of reported.

import QtQuick
import qs.core
import qs.platform.system


QtObject {
    id: root

    property string reported: ""

    function check() {
        checkRun.run(["crash", "check"]);
    }

    Component.onCompleted: root.check()

    // Prints "<epoch> <id>" for a crash to report, and nothing otherwise.
    readonly property CtlRun _check: CtlRun {
        id: checkRun
        tag: "crash"
        onFinished: (code, stdout) => {
            const id = stdout.trim().split(/\s+/)[1] ?? "";
            if (id.length > 0)
                root._report(id);
        }
    }

    function _report(id) {
        root.reported = id;
        Log.warn("crash", `the shell crashed and restarted itself (${id}); writing a report`);
        reportRun.run(["report", "create", "--reason", `crash ${id}`, "--crash", id]);
    }

    // Written locally and sent nowhere, like every report. It prints the
    // directory it wrote on stdout.
    readonly property CtlRun _reporter: CtlRun {
        id: reportRun
        tag: "crash"
        label: "report"
        onFinished: (code, stdout) => {
            const dir = stdout.trim().split("\n").pop();
            if (dir.length > 0)
                Log.warn("crash", `report written: ${dir} -- read it with 'report show', ask about it with 'ask --crash'`);
        }
    }
}
