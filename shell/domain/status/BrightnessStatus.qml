pragma Singleton

// Screen brightness, as powerdevil sees it, and KWin's Night Light.
//
// Both services stay where they are: powerdevil keeps handling the brightness
// keys and drawing their OSD, KWin keeps tinting the screen. What our
// renderer took away was only the applet that showed them -- Plasma keeps it
// inside its system tray, and our shell package has no tray of Plasma's.
//
// The displays are read with one busctl per display, all in one process,
// because powerdevil names them and a monitor can come and go. Any signal on
// the brightness object re-reads them all -- the Desktops rule -- except while
// a write is still on its way, when a re-read would drag a slider back to
// where it was a moment ago.
//
// Night Light is read by NightLight, the one reader of KWin's object, and
// shown from there. It had a read and a monitor of its own here, and every
// signal from it re-read every display too: a transition, which moves the
// temperature a step at a time, was a busctl per display per step.
//
// Night Light is suspended the way KWin's own shortcut does it: by invoking
// that shortcut. `inhibit` on the NightLight object is no use from here --
// KWin releases an inhibition when the connection that asked for it goes
// away, which for busctl is at once.

import QtQuick
import Quickshell.Io
import qs.domain.status.icons
import qs.platform.kde

QtObject {
    id: root

    readonly property string service: "org.kde.Solid.PowerManagement"
    readonly property string path: "/org/kde/ScreenBrightness"
    readonly property string displayIface: "org.kde.ScreenBrightness.Display"

    // [{ name, label, brightness, max, internal }], in powerdevil's order.
    property var displays: []

    // The names alone, as a string, so that a Repeater over them is rebuilt
    // when a monitor comes or goes and not every time a value moves.
    readonly property string displayNames: JSON.stringify(root.displays.map(d => d.name))

    // KWin's NightLight properties, as they are on the bus.
    readonly property var nightLight: NightLight.props

    readonly property string nightState: StatusIcons.nightLightState(root.nightLight)

    // When Night Light next changes, in the user's own time format. Nothing
    // in constant mode (3), which has no schedule, or while it is held off.
    readonly property string nightDetail: {
        const at = root.nightLight.scheduledTransitionDateTime ?? 0;
        if (!(at > 0) || root.nightLight.mode === 3)
            return "";
        const time = Qt.formatTime(new Date(at * 1000), Qt.locale().timeFormat(Locale.ShortFormat));
        switch (root.nightState) {
        case "day":
            return `Warmer from ${time}`;
        case "warm":
            return `Daylight again from ${time}`;
        default:
            return "";
        }
    }

    readonly property bool present: root.displays.length > 0 || root.nightState !== "unavailable"

    // The average across displays: it is one icon for all of them.
    readonly property real level: root.displays.length === 0 ? 0
        : root.displays.reduce((sum, d) => sum + d.brightness / d.max, 0) / root.displays.length

    readonly property string icon: StatusIcons.brightnessPanelIcon(root.level, root.displays.length > 0,
                                                                   root.nightState)
    readonly property string glyph: StatusIcons.brightnessPanelGlyph(root.level, root.displays.length > 0,
                                                                     root.nightState)

    function displayNamed(name) {
        return root.displays.find(d => d.name === name) ?? null;
    }

    // Shown at once, written in order. A drag across a slider asks for many
    // values in a row; only the latest per display is still worth sending by
    // the time the previous write returns -- which, over DDC to an external
    // monitor, takes a while.
    function setBrightness(name, value) {
        const display = root.displayNamed(name);
        if (!display)
            return;
        const v = Math.round(Math.max(0, Math.min(display.max, value)));
        root.displays = root.displays.map(d => d.name === name ? Object.assign({}, d, { brightness: v }) : d);
        const pending = Object.assign({}, root._pending);
        pending[name] = v;
        root._pending = pending;
        root._flush();
    }

    // One display at `percent` of its range, as a slider asks for it -- never
    // below the floor (StatusIcons.brightnessFromPercent).
    function setPercent(name, percent) {
        const display = root.displayNamed(name);
        if (display)
            root.setBrightness(name, StatusIcons.brightnessFromPercent(percent, display.max));
    }

    // Every display at `percent`, as one slider for all of them asks.
    function setAllPercent(percent) {
        for (const d of root.displays)
            root.setPercent(d.name, percent);
    }

    // Every display at once, by wheel notches, as the brightness keys do.
    function step(steps, stepPercent) {
        for (const d of root.displays)
            root.setBrightness(d.name, StatusIcons.stepBrightness(d.brightness, d.max, steps, stepPercent));
    }

    function toggleNightLight() {
        if (!["warm", "day", "suspended"].includes(root.nightState))
            return;
        Dbus.invokeShortcut("Toggle Night Color");
    }

    function refresh() {
        names.refresh();
    }

    function summary() {
        return {
            displays: root.displays,
            nightLight: root.nightState,
            temperature: root.nightLight.currentTemperature ?? 0,
            next: root.nightDetail,
            icon: root.icon
        };
    }

    property var _pending: ({})

    function _flush() {
        if (write.running)
            return;
        const name = Object.keys(root._pending)[0];
        if (name === undefined)
            return;
        const value = root._pending[name];
        const rest = Object.assign({}, root._pending);
        delete rest[name];
        root._pending = rest;
        // Flag 1 is powerdevil's SuppressIndicator: the slider under the
        // pointer is the indicator, and an OSD over it would be a second one.
        write.command = Dbus.callArgs(root.service, `${root.path}/${name}`, root.displayIface,
                                      "SetBrightness", "iu", [value, 1]);
        write.running = true;
    }

    readonly property Process _write: Process {
        id: write
        onRunningChanged: {
            if (running)
                return;
            root._flush();
            if (!write.running)
                settle.restart();
        }
    }

    readonly property DbusProperty _names: DbusProperty {
        id: names
        service: root.service
        path: root.path
        iface: "org.kde.ScreenBrightness"
        name: "DisplaysDBusNames"

        onLoaded: value => {
            const list = (value ?? []).filter(n => /^[A-Za-z0-9_]+$/.test(n));
            if (list.length === 0) {
                root.displays = [];
                return;
            }
            read.command = ["sh", "-c",
                            'for d; do printf "%s " "$d"; busctl --user --json=short call "$0" '
                            + '"/org/kde/ScreenBrightness/$d" org.freedesktop.DBus.Properties GetAll s '
                            + 'org.kde.ScreenBrightness.Display; done',
                            root.service].concat(list);
            read.running = false;
            read.running = true;
        }
        onAvailableChanged: if (!available) root.displays = []
    }

    readonly property Process _read: Process {
        id: read
        stdout: StdioCollector {
            onStreamFinished: {
                if (write.running || Object.keys(root._pending).length > 0)
                    return;
                root.displays = StatusIcons.brightnessDisplays(text.split("\n"));
            }
        }
    }

    // Signals come in bursts -- one per step of a drag, one per display --
    // so a re-read waits for the burst to end.
    readonly property Timer _settle: Timer {
        id: settle
        interval: 250
        onTriggered: root.refresh()
    }

    readonly property DbusWatch _brightnessWatch: DbusWatch {
        service: root.service
        path: root.path
        onChanged: if (!write.running) settle.restart()
    }
}
