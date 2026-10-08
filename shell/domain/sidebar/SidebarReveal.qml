pragma Singleton

// "The pointer was pushed against the sidebar's edge", heard from the daemon.
//
// A shell cannot see that push: the pointer is over somebody else's window.
// KWin can. `rmpr edges follow` binds the sidebar's side to one of the shell's
// own edge actions, and the edge script -- which follows the pointer in the
// last column on that side of every screen -- says when it comes to rest there
// and when it leaves, through the daemon, with no process in between
// (Resting; bin/windowsd/edges.py, kwin/edges). Resting there `restMs` is the
// push, on that screen. Which action it is depends on `sidebar.trigger`:
//
//   sidebar-reveal  ("drag") lights the grip where the pointer was, to be
//                   pressed and pulled -- SidebarHandle, on that screen only
//   sidebar-open    ("hover") opens the sidebar on that screen, as one that
//                   goes away again once the pointer has left it
//
// Resting, rather than one of KWin's own screen edges: KWin has an edge only on
// the outside of the whole layout, so a side another screen meets had no
// trigger at all -- and where it has one, it draws its approach glow down the
// whole length of it. Against the outside the pointer cannot go further, and
// against a neighbour KWin's edge barrier holds it there a moment before it
// crosses, so every screen has the same trigger this way. Reached is the
// other route, for an edge KWin does have -- a sidebar action bound to the
// top or the bottom by hand.
//
// Opening it here, rather than through `rmpr sidebar` as an edge bound to the
// key's own action does, is the difference between the sidebar being there
// as the pointer arrives and being there a second later, after a shell, a
// one-shot KWin script and two trips across the bus.
//
// A match rule rather than a whole-bus monitor, for the reason the window list
// gives: this wants one signal, not every message on the session bus.

import QtQuick
import Quickshell
import qs.core
import qs.platform.kde
import qs.domain.sidebar.gesture
import qs.domain.surfaces

QtObject {
    id: root

    // Pushed into, at (x, y) in the compositor's coordinates, on `output` --
    // which only the handle on that output answers. An edge that did not say
    // where (a script from before it did) is at -1, -1 on "", and every
    // handle answers it with its grip in the middle.
    signal revealed(string output, real x, real y)

    function reached(action, x, y, output) {
        if (action === "sidebar-reveal") {
            root.revealed(output, x, y);
            return;
        }
        if (action === "sidebar-open") {
            Surfaces.openSidebar(Gesture.screenFor(output, x, y, Quickshell.screens), "edge");
            return;
        }
        Log.warn("sidebar", `an edge asked for '${action}', which the shell does not do`);
    }

    // How long the pointer has to rest against the edge to count as a
    // push. Long enough that crossing to the next screen -- through the
    // barrier, in a flick -- is not one; short enough that the barrier still
    // holds a pointer that is being pushed.
    readonly property int restMs: 200

    // The rest being timed: { action, x, y, output }, or null.
    property var _rest: null

    function resting(action, x, y, output, on) {
        if (on) {
            root._rest = { action: action, x: x, y: y, output: output };
            restTimer.restart();
            return;
        }
        if (!root._rest || root._rest.action !== action || root._rest.output !== output)
            return;
        root._rest = null;
        restTimer.stop();
    }

    readonly property Timer _restTimer: Timer {
        id: restTimer
        interval: root.restMs
        onTriggered: {
            const r = root._rest;
            root._rest = null;
            if (r)
                root.reached(r.action, r.x, r.y, r.output);
        }
    }

    readonly property BusMonitor _monitor: BusMonitor {
        match: `type='signal',interface='${Branding.dbusName}.Edges'`

        onRead: line => {
            const msg = BusLine.parse(line);
            const iface = `${Branding.dbusName}.Edges`;
            if (BusLine.isSignal(msg, iface, "Resting")) {
                const rest = BusLine.payload(msg, 5);
                if (rest)
                    root.resting(String(rest[0]), Number(rest[1]), Number(rest[2]), String(rest[3]), rest[4] === true);
                return;
            }
            if (!BusLine.isSignal(msg, iface, "Reached"))
                return;
            const data = BusLine.payload(msg, 1);
            if (!data)
                return;
            const placed = data.length >= 4;
            root.reached(String(data[0]),
                         placed ? Number(data[1]) : -1,
                         placed ? Number(data[2]) : -1,
                         placed ? String(data[3]) : "");
        }
    }
}
