pragma Singleton

// "Open this where the pointer is", heard from the session daemon.
//
// Wayland tells a client where the pointer is only while it is over that
// client's own surface, so a shell cannot ask the question at all. KWin can:
// `rmpr clipboard` loads a one-shot KWin script that reads
// `workspace.cursorPos`, hands it to the daemon, and the daemon emits the
// signal this listens for. The whole route is in bin/windowsd.py.in's Pointer.
//
// A match rule rather than a whole-bus monitor, for the reason the window list
// gives: this wants one signal, not every message on the session bus.

import QtQuick
import Quickshell.Io
import qs.core

QtObject {
    id: root

    readonly property Process _monitor: Process {
        running: true
        command: ["busctl", "--user", "--json=short", "monitor",
                  "--match", `type='signal',interface='${Branding.dbusName}.Pointer'`]

        stdout: SplitParser {
            onRead: line => {
                const msg = BusLine.parse(line);
                if (!BusLine.isSignal(msg, `${Branding.dbusName}.Pointer`, "Requested"))
                    return;
                const data = BusLine.payload(msg, 4);
                if (!data)
                    return;
                root.requested(String(data[0]), Number(data[1]), Number(data[2]), String(data[3]));
            }
        }
    }

    // action, and where in the compositor's own coordinates. Listened to by
    // shell.qml, which is where the surfaces are.
    signal requested(string action, real x, real y, string output)
}
