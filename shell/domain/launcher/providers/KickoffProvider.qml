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
//
// Placement is plasmashell's, not ours. The menu appears at whichever panel
// holds the launcher applet, which is usually not where our panel is -- so a
// panel at the top can open a menu at the bottom. There is no way to anchor it
// from here: the window belongs to plasmashell, and chasing another process's
// popup geometry on Wayland is not something to attempt.
//
// The fix is structural rather than clever: when this shell owns the active
// Plasma shell package, that package's only panel is a hidden host carrying
// the launcher applet, placed on the same edge as our panel. Until then, the
// built-in provider is the one that opens where the button is.

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

    // Placement is not ours to control, and a menu appearing on the far side of
    // the screen looks like a bug rather than a limitation, so it is said once
    // rather than left to be discovered.
    property bool _warned: false

    function open(mode) {
        if (!root._warned && root.mode === "menu") {
            root._warned = true;
            Log.info("launcher", "kickoff opens at plasmashell's own panel, not ours; use launcher.provider \"builtin\" for a menu anchored to the panel button");
        }
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
