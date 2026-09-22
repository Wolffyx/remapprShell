pragma Singleton

// This shell's global shortcuts, heard directly from kglobalaccel.
//
// What this replaces. A key press travelled kglobalaccel -> the session
// daemon -> `rmpr` (bash) -> `quickshell ipc` -> the shell: four processes,
// two of them spawned per press, measured at about 200 ms. They are detached,
// so they race -- a quick Alt+Tab could deliver its release before its press,
// and the switcher stayed on screen with nothing left to close it. That is not
// one bug; it is the shape that produces them, and it is why this shell's own
// Alt+Tab lost to KWin's.
//
// kglobalaccel already announces every press on the session bus. The shell
// already reads the bus this way for the window list, notifications and the
// OSD. So it listens, and the chain has no links left.
//
// The daemon is still what *owns* the component: a shortcut is only grabbed
// while its component has a running owner, which is the whole reason
// bin/windowsd.py.in registers them. It no longer runs anything for the
// actions listed here -- see SHELL_ACTIONS there, which names this file.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.shortcuts.events

QtObject {
    id: root

    // The actions the shell answers itself.
    //
    // Not every action, and the ones left out are left out for a reason.
    //
    // `clipboard` and `sidebar` open where the pointer is, and Wayland tells a
    // client the pointer's position only over its own surfaces -- that answer
    // has to come from a KWin script, so those two keep the route through the
    // daemon. `ask` builds a redacted report before anything is shown, which
    // is the CLI's work and not a surface. The screenshot keys keep the route
    // too, because they are the only ones worth anything when the shell is
    // not running at all.
    readonly property var handled: [
        "launcher", "search", "settings", "keys",
        "switcher", "switcher-reverse", "overview", "overview-reverse"
    ]

    function takes(action) {
        return root.handled.indexOf(action) >= 0;
    }

    // Acted on by shell.qml, which is where the surfaces are.
    signal pressed(string action)
    signal released(string action)

    // A match rule rather than a whole-bus monitor, and narrowed to this
    // component's own object path as well as the interface: every shell on the
    // machine announces its keys here, and there is no reason for ours to see
    // theirs go past.
    readonly property Process _monitor: Process {
        running: true
        command: ["busctl", "--user", "--json=short", "monitor",
                  "--match", `type='signal',interface='${ShortcutEvents.interfaceName}',path='${ShortcutEvents.pathFor(Branding.slug)}'`]

        stdout: SplitParser {
            onRead: line => {
                const event = ShortcutEvents.parse(line, Branding.slug);
                if (!event || !root.takes(event.action))
                    return;
                if (event.kind === "pressed")
                    root.pressed(event.action);
                else
                    root.released(event.action);
            }
        }

        onRunningChanged: if (running)
            Log.info("shortcuts", "listening for this shell's own keys");
    }
}
