// Reads one DBus property, declaratively.
//
// Nothing subscribes to a property directly: DBus property change signals are
// inconsistently emitted across KDE services, so a DbusWatch tells this to
// refresh and the value is re-read. Re-reading is cheap and always correct,
// where trusting a change signal is neither.

import QtQuick
import Quickshell.Io
import qs.core

QtObject {
    id: root

    required property string service
    required property string path
    required property string iface
    required property string name

    property var value: undefined
    property bool available: false

    signal loaded(var value)

    function refresh() {
        proc.running = false;
        proc.running = true;
    }

    readonly property Process _proc: Process {
        id: proc
        command: Dbus.propertyArgs(root.service, root.path, root.iface, root.name)

        stdout: StdioCollector {
            onStreamFinished: {
                const v = Dbus.unwrap(text, `${root.iface}.${root.name}`);
                root.available = v !== undefined;
                if (root.available) {
                    root.value = v;
                    root.loaded(v);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    root.available = false;
                    Log.debug("dbus", `${root.iface}.${root.name}: ${text.trim()}`);
                }
            }
        }
    }

    Component.onCompleted: root.refresh()
}
