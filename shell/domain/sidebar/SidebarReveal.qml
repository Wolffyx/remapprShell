pragma Singleton

// "The pointer was pushed into the sidebar's edge", heard from the daemon.
//
// The sidebar's grab strip lies over the edge of whatever window is there, and
// a press on it cannot be handed on to that window -- so it takes nothing
// until the pointer is pushed into the edge, and then lights up for a moment
// to be pulled. A shell cannot see that push: the pointer is over somebody
// else's window. KWin can. `rmpr edges follow` binds the edge to
// `sidebar-reveal`, the edge script calls the daemon's Triggered with it, and
// the daemon -- which runs a command for every other action -- announces this
// one as Reached for the shell to hear, with no process in between
// (bin/windowsd/edges.py). SidebarHandle is what lights.
//
// A match rule rather than a whole-bus monitor, for the reason the window list
// gives: this wants one signal, not every message on the session bus.

import QtQuick
import qs.core
import qs.platform.kde

QtObject {
    id: root

    // Pushed into, on whichever screen has that edge.
    signal revealed()

    readonly property BusMonitor _monitor: BusMonitor {
        match: `type='signal',interface='${Branding.dbusName}.Edges',member='Reached'`

        onRead: line => {
            const msg = BusLine.parse(line);
            if (!BusLine.isSignal(msg, `${Branding.dbusName}.Edges`, "Reached"))
                return;
            const data = BusLine.payload(msg, 1);
            if (!data)
                return;
            const action = String(data[0]);
            if (action === "sidebar-reveal")
                root.revealed();
            else
                Log.warn("sidebar", `an edge asked for '${action}', which the shell does not do`);
        }
    }
}
