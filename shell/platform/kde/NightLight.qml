pragma Singleton

// KWin's own idea of whether it is day or night.
//
// Plasma has no automatic light/dark theme switching -- its sunset switching
// belongs to the wallpaper -- but Night Light, which warms the screen after
// sunset, knows exactly when night begins. It publishes that as a property, on
// the schedule the user has already configured in System Settings, whether
// that is their location's sunrise and sunset or times they typed in. So the
// shell can turn dark when the screen warms, on one schedule, rather than
// keeping a second clock of its own and disagreeing with the desktop about
// when night is.
//
// `known` is false when Night Light is missing, unsupported or switched off.
// Nothing should guess in that case: there is no schedule to follow, and the
// caller falls back to whatever it did before.
//
// This is the one reader of KWin's NightLight object. The brightness widget
// shows the same properties -- the temperature, whether it is held off, when
// it next changes -- and used to read them again, with a monitor of its own
// on the same object; every tick of a transition then re-read every display
// as well. It binds to `props` here instead.

import QtQuick
import Quickshell.Io
import qs.core

QtObject {
    id: root

    readonly property string service: "org.kde.KWin"
    readonly property string path: "/org/kde/KWin/NightLight"
    readonly property string iface: "org.kde.KWin.NightLight"

    // Every property of the object, as it is on the bus: { available,
    // enabled, inhibited, daylight, currentTemperature, mode,
    // scheduledTransitionDateTime, ... }. Empty until KWin first answers.
    // A read that gets no answer leaves the last one standing, as each
    // property read on its own used to: KWin going quiet for a moment is
    // not Night Light going away.
    property var props: ({})

    // True while the sun is up, by KWin's reckoning.
    readonly property bool daylight: root.props.daylight === true

    // Whether that answer means anything.
    //
    // All three arrive together, in one reply. They used to be three reads,
    // answering one by one, and a binding re-evaluated between them said
    // "night" for an instant on every start -- the shell flashed dark before
    // going light. `daylight` must still be there: an object that answers
    // without it has no schedule to follow.
    readonly property bool known: root.props.available === true
                                  && root.props.enabled === true
                                  && root.props.daylight !== undefined

    onKnownChanged: Log.info("theme", root.known
        ? `night light: ${root.daylight ? "daylight" : "night"}, and it says when that changes`
        : "night light: off or unavailable; nothing says when night is");

    onDaylightChanged: if (root.known)
        Log.info("theme", `night light: ${root.daylight ? "daylight" : "night"}`);

    function refresh() {
        getAll.running = false;
        getAll.running = true;
    }

    readonly property Process _getAll: Process {
        id: getAll
        command: Dbus.callArgs(root.service, root.path, "org.freedesktop.DBus.Properties",
                               "GetAll", "s", [root.iface])
        stdout: StdioCollector {
            onStreamFinished: {
                const reply = Dbus.unwrap(text, "NightLight");
                if (reply !== undefined)
                    root.props = BusLine.props(reply);
            }
        }
    }

    // The properties are re-read rather than taken from the signal: see
    // DbusProperty for why every consumer here does that.
    readonly property DbusWatch _watch: DbusWatch {
        service: root.service
        path: root.path
        onChanged: root.refresh()
    }

    // Night falls at a moment nothing else is happening, and a monitor that
    // died takes the only notification with it. Cheap enough to ask again.
    readonly property Timer _poll: Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
