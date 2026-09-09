// KDE's own search and command runner.
//
// KRunner is DBus-activatable, so it need not be running to be opened, and it
// positions and dismisses itself. Nothing here draws anything.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.launcher

Provider {
    id: root

    providerId: "krunner"
    label: "KRunner"

    readonly property Process _probe: Process {
        running: true
        command: ["busctl", "--user", "--json=short", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Activatable counts as available: KRunner is usually not
                // running until something asks for it.
                root.available = text.includes("org.kde.krunner");
                Log.debug("launcher", `krunner available: ${root.available}`);
            }
        }
    }

    readonly property Process _call: Process {}

    function _invoke(method, args) {
        root._call.running = false;
        root._call.command = ["busctl", "--user", "call", "org.kde.krunner", "/App",
                              "org.kde.krunner.App", method].concat(args ?? []);
        root._call.running = true;
    }

    function open(mode) { root._invoke("display", []); }
    function openWithQuery(query) { root._invoke("query", ["s", query]); }
    function close() { root._invoke("display", []); }
    function toggle(mode) { root._invoke("toggleDisplay", []); }
}
