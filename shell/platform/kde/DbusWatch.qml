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

    readonly property Process _proc: Process {
        command: ["gdbus", "monitor", "--session", "--dest", root.service, "--object-path", root.path]
        running: root.running

        stdout: SplitParser {
            onRead: line => {
                // gdbus prints two banner lines before any signal.
                if (line.startsWith("Monitoring signals") || line.startsWith("The name "))
                    return;
                if (root.filter.length > 0 && !line.includes(root.filter))
                    return;
                root.changed(line);
            }
        }

        // Process.exited carries a QProcess::ExitStatus that QML cannot name,
        // so the exit is noticed through `running` instead of that signal.
        onRunningChanged: {
            if (!running && root.running)
                Log.warn("dbus", `monitor for ${root.service}${root.path} stopped unexpectedly`);
        }
    }
}
