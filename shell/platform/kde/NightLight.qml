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

import QtQuick
import qs.core

QtObject {
    id: root

    readonly property string service: "org.kde.KWin"
    readonly property string path: "/org/kde/KWin/NightLight"
    readonly property string iface: "org.kde.KWin.NightLight"

    // True while the sun is up, by KWin's reckoning.
    readonly property bool daylight: _daylight.value === true

    // Whether that answer means anything.
    //
    // Read from the value, not from `available`: DbusProperty sets `available`
    // and then the value, and a binding is re-evaluated between the two
    // statements -- so this said "night" for an instant on every start, with
    // the value not yet in, and the shell flashed dark before going light.
    readonly property bool known: _available.value === true
                                  && _enabled.value === true
                                  && _daylight.value !== undefined

    onKnownChanged: Log.info("theme", root.known
        ? `night light: ${root.daylight ? "daylight" : "night"}, and it says when that changes`
        : "night light: off or unavailable; nothing says when night is");

    onDaylightChanged: if (root.known)
        Log.info("theme", `night light: ${root.daylight ? "daylight" : "night"}`);

    function refresh() {
        _available.refresh();
        _enabled.refresh();
        _daylight.refresh();
    }

    readonly property DbusProperty _available: DbusProperty {
        service: root.service; path: root.path; iface: root.iface; name: "available"
    }

    readonly property DbusProperty _enabled: DbusProperty {
        service: root.service; path: root.path; iface: root.iface; name: "enabled"
    }

    readonly property DbusProperty _daylight: DbusProperty {
        service: root.service; path: root.path; iface: root.iface; name: "daylight"
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
