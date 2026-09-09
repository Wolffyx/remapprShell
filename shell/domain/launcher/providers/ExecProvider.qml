// Any launcher that is its own process: rofi, fuzzel, walker, or a command the
// user supplies.
//
// These are layer-shell clients that position and dismiss themselves, so this
// only starts them. A query is passed by substituting %q in the command, which
// is how a provider can be driven from a panel search box without this file
// knowing anything about the program it is running.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.launcher

Provider {
    id: root

    // The command to run. First element is probed to decide availability.
    property var command: []

    readonly property string binary: root.command.length > 0 ? root.command[0] : ""

    // `command -v` writes the resolved path on success and nothing on failure,
    // so availability is read from the output rather than the exit code --
    // Process.exited carries a type QML cannot name, which makes the exit code
    // awkward to reach from a handler.
    readonly property Process _probe: Process {
        running: root.binary.length > 0
        command: ["sh", "-c", "command -v \"$1\" 2>/dev/null || true", "sh", root.binary]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim().length > 0;
                Log.debug("launcher", `${root.providerId} available: ${root.available}`);
            }
        }
    }

    readonly property Process _run: Process {}

    function _start(query) {
        if (root.command.length === 0)
            return;
        root._run.running = false;
        root._run.command = root.command.map(a => a === "%q" ? (query ?? "") : a);
        root._run.running = true;
    }

    function open(mode) { root._start(""); }
    function openWithQuery(query) { root._start(query); }
    function close() {}
}
