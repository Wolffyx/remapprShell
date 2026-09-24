// Runs the control binary, and says so in the journal when it fails.
//
// The CLI is the one implementation of everything it does -- theming the
// desktop, following an edge, writing a report -- and the shell asks it
// rather than doing the same thing a second way in QML. Five places did the
// asking with a Process of their own, each logging a failure its own way or
// not at all. A command that fails and says nothing is what once sent a whole
// session looking for a missing click, so here a failure always says so.
//
// One run at a time: run() again while one is going stops it and starts the
// new one, which is what every caller did by hand.
//
// A plain object, owned by whoever asks: one per kind of command, so each
// keeps its own last output.

import QtQuick
import Quickshell.Io
import qs.core

QtObject {
    id: root

    // The journal scope its lines go under: "theme", "panel", "crash".
    property string tag: "ctl"

    // What its lines call the command. The arguments of the last run when
    // left empty: "theme variant dark".
    property string label: ""

    // How loudly a failure is logged -- "warn" (the default), "info" or
    // "debug". A failure is a non-zero exit, logged with the last line the
    // command wrote to stderr. What a command that succeeded wrote to stderr
    // is its progress, and is logged at debug whatever this says.
    property string level: "warn"

    readonly property bool running: proc.running

    // The arguments of the last run, without the binary.
    property var args: []

    // After every run, the stopped ones included: the exit code, and all of
    // stdout and stderr as the command left them. Not emitted for a command
    // that could not be started at all -- Quickshell warns about that itself.
    signal finished(int code, string stdout, string stderr)

    function run(args) {
        root.args = (args ?? []).map(a => String(a));
        proc.running = false;
        proc.command = [Branding.ctlBin].concat(root.args);
        proc.running = true;
    }

    function _log(level, message) {
        if (level === "debug")
            Log.debug(root.tag, message);
        else if (level === "info")
            Log.info(root.tag, message);
        else
            Log.warn(root.tag, message);
    }

    readonly property Process _proc: Process {
        id: proc
        stdout: StdioCollector { id: out }
        stderr: StdioCollector { id: err }
    }

    // Through Connections rather than an onExited handler, whose exit-status
    // parameter the linter cannot resolve. Quickshell ends both streams
    // before it emits `exited`, so the collectors are complete by now.
    readonly property Connections _exit: Connections {
        target: proc

        function onExited(code: int): void {
            const name = root.label.length > 0 ? root.label : root.args.join(" ");
            const last = err.text.trim().split("\n").pop();
            if (code !== 0)
                root._log(root.level, `${name} exited ${code}${last.length > 0 ? `: ${last}` : ""}`);
            else if (last.length > 0)
                Log.debug(root.tag, `${name}: ${last}`);
            root.finished(code, out.text, err.text);
        }
    }
}
