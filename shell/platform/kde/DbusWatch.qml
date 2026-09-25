// Watches a DBus object and reports that something on it changed.
//
// It deliberately does NOT parse the signal payload. Every consumer re-reads
// the properties it cares about, which is both simpler than decoding GVariant
// out of gdbus's text output and correct when a service emits a signal whose
// payload is incomplete.

import QtQuick
import Quickshell.Io
import qs.core

QtObject {
    id: root

    required property string service
    required property string path

    // Only signals whose line contains this are reported. Empty means all.
    property string filter: ""

    property bool running: true

    signal changed(string line)

    // gdbus prints two banner lines before any signal, the second saying
    // whether the name has an owner yet. After that, "The name ... is owned
    // by" means the service has just (re)appeared: everything on it is new,
    // whatever `filter` says. The shell starts with Plasma's core, before
    // powerdevil and the rest of the workspace, so this is how it learns of
    // them -- a read at startup found nothing there.
    property bool _banner: true

    readonly property Process _proc: Process {
        command: ["gdbus", "monitor", "--session", "--dest", root.service, "--object-path", root.path]
        running: root.running

        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("Monitoring signals"))
                    return;
                if (line.startsWith("The name ")) {
                    if (!root._banner && line.includes(" is owned by "))
                        root.changed(line);
                    root._banner = false;
                    return;
                }
                if (root.filter.length > 0 && !line.includes(root.filter))
                    return;
                root.changed(line);
            }
        }

        // Process.exited carries a QProcess::ExitStatus that QML cannot name,
        // so the exit is noticed through `running` instead of that signal.
        onRunningChanged: {
            if (running)
                root._banner = true;
            else if (root.running)
                Log.warn("dbus", `monitor for ${root.service}${root.path} stopped unexpectedly`);
        }
    }
}
