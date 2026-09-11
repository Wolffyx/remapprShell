pragma Singleton

// Feral's GameMode, switched on and off from the shell.
//
// GameMode is on while at least one registered program runs. `gamemoderun`
// registers whatever it starts, so "on" is a `sleep` started under it, and
// "off" is stopping that sleep; GameMode notices the program is gone and
// undoes its changes. Nothing is left behind if the shell stops: the sleep
// goes with it. Absent where gamemoderun is not installed.

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool available: false
    readonly property bool active: holder.running

    function set(on) {
        if (!root.available)
            return;
        holder.running = on;
    }

    function toggle() {
        root.set(!root.active);
    }

    readonly property Process _probe: Process {
        command: ["sh", "-c", "command -v gamemoderun"]
        running: true
        onExited: code => root.available = code === 0
    }

    readonly property Process _holder: Process {
        id: holder
        command: ["gamemoderun", "sleep", "infinity"]
    }
}
