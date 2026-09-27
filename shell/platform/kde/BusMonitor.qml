// One `busctl monitor` narrowed by a match rule, handed over a line at a time.
//
// Five listeners in this shell watch the session bus this way -- the window
// list, notifications, the OSD, the shell's own keys, pointer requests -- and
// each built the same process by hand. What they do with a line is theirs,
// and stays theirs: this does not parse. BusLine is what makes a line safe to
// hand to JSON.parse, and every parser here goes through it.
//
// A match rule, always, rather than a whole-bus monitor. Eavesdropping on
// everything to catch one signal would put every message on the session bus
// through a process of ours, other applications' payloads included.
//
// What it adds is a count of its own drops. BusLine counts lines too large to
// parse in one global counter, and each listener used to compare that with a
// copy of its own -- so a drop in one listener could be reported by another.
// The count here is taken around this monitor's own `read`, and nothing else
// runs in between.

import QtQuick
import Quickshell.Io
import qs.core

QtObject {
    id: root

    // The rule, as busctl and dbus-daemon spell it:
    // "type='signal',interface='org.kde.osdService'".
    required property string match

    // Whether it should be listening. Turned off, the process is stopped.
    property bool running: true

    // Whether it is: the process is up. A listener says so in the journal
    // when this changes, in its own words.
    readonly property bool listening: proc.running

    // One line of `busctl --json=short monitor`, exactly as it came.
    signal read(string line)

    // Handling the last line dropped `n` messages too large to read safely --
    // see BusLine.maxLength. Emitted after `read` has returned.
    signal dropped(int n)

    readonly property Process _proc: Process {
        id: proc
        command: Dbus.busctl.concat(["monitor", "--match", root.match])
        running: root.running

        stdout: SplitParser {
            onRead: line => {
                const before = BusLine.dropped;
                root.read(line);
                const n = BusLine.dropped - before;
                if (n > 0)
                    root.dropped(n);
            }
        }
    }
}
