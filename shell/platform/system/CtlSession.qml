// A settings page's conversation with one CLI command.
//
// Six settings pages -- appearance, windows, edges, lock screen, switching,
// shortcuts -- each show what a command reports with `status --json`, change
// it by running the same command, and read the status again once that is
// done, putting the command's own error line in front of the user when it
// refuses. Each had the same two processes and the same four properties;
// this is them, once.
//
// A plain object, owned by the page:
//
//     readonly property CtlSession ctl: CtlSession {
//         prefix: ["windows", "behaviour"]
//         readFailed: "Could not read KWin's window settings."
//     }
//
// and then ctl.state, ctl.status, ctl.busy, ctl.refresh(), ctl.run(["set", id, value]).
// Nothing is read until refresh() is called: a page does that when it is
// built.

import QtQuick
import qs.core

QtObject {
    id: root

    // The command's words before its verb: ["theme"], or ["windows", "behaviour"].
    property var prefix: []

    // What the page says when the status cannot be read.
    property string readFailed: "Could not read the current state."

    // Where a status that fails to parse is logged, and what the line calls
    // it: "settings", "theme status".
    property string logScope: "settings"
    property string logLabel: `${root.prefix.join(" ")} status`

    // How the command's last error line is cut down to what a person reads:
    // everything up to and including "error:" goes. Most commands' pages
    // accept "error" without the colon too; the shortcuts page asks for it,
    // /^.*error:\s*/i.
    property var errorPrefix: /^.*error:?\s*/i

    // `<prefix> status --json`, parsed. Null until the first read returns.
    property var state: null

    // The last thing the page should say: the command's own error line, or
    // readFailed. Cleared by run().
    property string status: ""

    // A change is running; another is refused until it is done.
    readonly property bool busy: root._run.running

    function refresh() {
        root._read.run(root.prefix.concat(["status", "--json"]));
    }

    // Every argument goes as a string: run(["set", "borderless", true]) runs
    // `... set borderless true`.
    function run(args) {
        if (root.busy)
            return;
        root.status = "";
        root._run.run(root.prefix.concat(args ?? []));
    }

    readonly property CtlRun _read: CtlRun {
        tag: root.logScope
        level: "debug"
        onFinished: (code, stdout) => {
            try {
                root.state = JSON.parse(stdout);
            } catch (e) {
                root.status = root.readFailed;
                Log.warn(root.logScope, `${root.logLabel}: ${e}`);
            }
        }
    }

    // Read again once a change has run, whether or not it worked: the
    // status is what is true now, whichever it was.
    readonly property CtlRun _run: CtlRun {
        tag: root.logScope
        level: "debug"
        onFinished: (code, stdout, stderr) => {
            const errors = stderr.split("\n").filter(l => /error/i.test(l));
            if (errors.length > 0)
                root.status = errors.pop().replace(root.errorPrefix, "");
        }
        onRunningChanged: if (!running) root.refresh()
    }
}
