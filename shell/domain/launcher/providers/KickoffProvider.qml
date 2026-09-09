// Plasma's own application menu.
//
// Kickoff cannot be embedded. It ships as a C++ applet
// (/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.kickoff.so) with its QML
// inside the binary, not as a filesystem package, so there is nothing for a
// Quickshell window to import. The only ways to get the real Kickoff are to
// ask plasmashell to show it, or to run it in its own window.
//
//   menu      org.kde.PlasmaShell.activateLauncherMenu(). Shows the genuine
//             menu, but only if the active shell package's panel contains a
//             launcher applet -- otherwise it silently does nothing.
//   windowed  plasmawindowed, which opens it as an ordinary window. Slower to
//             start and it will not dismiss itself on focus loss.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.launcher

Provider {
    id: root

    providerId: "kickoff"
    label: "Application menu (Kickoff)"

    // "menu" or "windowed".
    property string mode: "menu"

    readonly property Process _probe: Process {
        running: true
        command: ["busctl", "--user", "--json=short", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.includes("org.kde.plasmashell");
                Log.debug("launcher", `kickoff available: ${root.available} (plasmashell)`);
            }
        }
    }

    readonly property Process _call: Process {}

    function open(mode) {
        root._call.running = false;
        if (root.mode === "windowed") {
            root._call.command = ["plasmawindowed", "org.kde.plasma.kickoff"];
        } else {
            root._call.command = ["busctl", "--user", "call", "org.kde.plasmashell",
                                  "/PlasmaShell", "org.kde.PlasmaShell", "activateLauncherMenu"];
        }
        root._call.running = true;
    }

    function close() {}
}
