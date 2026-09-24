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
//
// Which is why "is plasmashell running" is not the availability question.
// `activateLauncherMenu` shows the menu attached to a launcher applet in the
// active shell package's layout, and does nothing at all when there is none --
// exactly the case under our own renderer, whose package deliberately has no
// panel. Reported as available there, it becomes the automatic choice and the
// start button silently does nothing.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.kde
import qs.platform.system
import qs.domain.launcher

Provider {
    id: root

    providerId: "kickoff"
    label: "Application menu (Kickoff)"

    // "menu" or "windowed".
    property string mode: "menu"

    // Two conditions, and both have to hold.
    property bool _plasmashellRunning: false

    readonly property Process _probe: Process {
        running: true
        command: ["busctl", "--user", "--json=short", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._plasmashellRunning = text.includes("org.kde.plasmashell");
                root._hostView.reload();
            }
        }
    }

    // Which package plasmashell is drawing. Watched, because switching the
    // renderer changes it and the answer to "can Kickoff open" changes with it.
    property string _shellPackage: "org.kde.plasma.desktop"

    readonly property FileView _shellrc: FileView {
        path: `${Env.xdgConfigHome()}/plasmashellrc`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        // In [Shell], where plasmashell and every script here read it.
        onLoaded: {
            const next = Ini.value(text(), "Shell", "ShellPackage") || "org.kde.plasma.desktop";
            if (next !== root._shellPackage) {
                root._shellPackage = next;
                root._hostView.reload();
            }
        }
        onLoadFailed: root._hostView.reload()
    }

    // That package's applet layout, which is where a launcher applet would be.
    readonly property FileView _hostView: FileView {
        path: `${Env.xdgConfigHome()}/plasma-${root._shellPackage}-appletsrc`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root._update(text())
        onLoadFailed: root._update("")
    }

    // A launcher applet, not merely a panel: a panel without one has nothing
    // for the menu to attach to, and the call is just as silent.
    property bool _probed: false

    function _update(layout) {
        const hasHost = /^plugin=org\.kde\.plasma\.(kickoff|kicker|dashboard)$/m.test(layout ?? "");
        const next = root._plasmashellRunning && hasHost;
        // Logged on the first determination as well as on a change: this
        // provider starts unavailable, so a shell that never had it would
        // otherwise never say why the obvious choice was not taken.
        if (next !== root.available || !root._probed) {
            root._probed = true;
            root.available = next;
            Log.info("launcher", next
                ? `kickoff can open: ${root._shellPackage} has a launcher applet`
                : `kickoff unavailable: ${root._shellPackage} has no launcher applet to open it at`);
        }
    }

    // The windowed menu is a process of its own, and opening it again
    // replaces the last one rather than stacking a second window.
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
            root._call.running = true;
        } else {
            Dbus.send("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "activateLauncherMenu");
        }
    }

    function close() {}
}
