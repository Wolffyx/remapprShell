pragma Singleton

// Our own on-screen display, off by default.
//
// Plasma owns the OSD. This does not take it over: plasmashell emits
// `osdProgress` and `osdText` on org.kde.osdService as plain DBus signals, so
// we listen and draw. Nothing is claimed, nothing is replaced, and turning this
// off leaves Plasma exactly as it was.
//
// It is off by default for the reason every replacement in this project is:
// Plasma's OSD already works. What ours buys is a layer-shell surface -- our
// own placement, our own animation -- for someone who wants that.
//
// With our Look-and-Feel package active, Plasma draws OUR OSD QML, so enabling
// this without silencing that one shows two. `rmpr theme osd ours` is what
// silences it; the settings page says so, and so does `rmpr doctor`.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.config
import qs.domain.osd.events

QtObject {
    id: root

    readonly property bool enabled: ConfigStore.value("osd.enabled", false) === true
    readonly property int timeout: ConfigStore.value("osd.timeout", 1800)

    property bool showing: false
    property string icon: ""
    property string text: ""
    property real value: 0
    property real maxValue: 100
    property bool showingProgress: false

    function _show(event) {
        root.icon = event.icon;
        root.text = event.text;
        root.value = event.value;
        root.maxValue = event.maxValue;
        root.showingProgress = event.showingProgress;
        root.showing = true;
        root._hideTimer.restart();
        Log.debug("osd", `${event.showingProgress ? `${event.value}/${event.maxValue}` : event.text} (${event.icon})`);
    }

    readonly property Timer _hideTimer: Timer {
        interval: root.timeout
        onTriggered: root.showing = false
    }

    // A match rule rather than a whole-bus monitor: eavesdropping on
    // everything to catch two signals would put every message on the session
    // bus through this process, including other applications' payloads.
    readonly property Process _monitor: Process {
        command: ["busctl", "--user", "--json=short", "monitor",
                  "--match", "type='signal',interface='org.kde.osdService'"]
        running: root.enabled

        stdout: SplitParser {
            onRead: line => {
                const event = OsdEvents.parse(line);
                if (event)
                    root._show(event);
            }
        }

        onRunningChanged: {
            if (running)
                Log.info("osd", "listening for Plasma's OSD signals");
            else if (root.enabled)
                Log.warn("osd", "the OSD listener stopped; nothing will be drawn");
        }
    }
}
