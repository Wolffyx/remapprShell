pragma Singleton

// Our own on-screen display, off by default.
//
// Two inputs, and the second is why this is not only a listener any more.
//
// Plasma owns the OSD, and this does not take it over: plasmashell emits
// `osdProgress` and `osdText` on org.kde.osdService as plain DBus signals, so
// we listen and draw. Nothing is claimed, nothing is replaced, and turning this
// off leaves Plasma exactly as it was. That input carries everything we do not
// read ourselves -- keyboard layout, touchpad, caps lock.
//
// But a listener draws nothing where nothing is emitted. On this machine
// (measured 2026-09-16) plasmashell receives `volumeChanged` on the bus and
// emits no signal at all, so both OSDs were silent: Plasma's, and ours behind
// it. The volume and brightness this shell already reads for its own panel
// widgets are the same facts Plasma would have been reporting, so they drive
// the OSD directly -- no daemon, no ownership, and no dependence on a
// plasmashell that has stopped speaking.
//
// It is off by default for the reason every replacement in this project is:
// Plasma's OSD already works. What ours buys is a layer-shell surface -- our
// own placement, our own animation -- for someone who wants that.
//
// With our Look-and-Feel package active, Plasma draws OUR OSD QML, so enabling
// this without silencing that one shows two. `rmpr theme osd ours` is what
// silences it; the settings page says so, and so does `rmpr doctor`.

import QtQuick
import qs.core
import qs.platform.kde
import qs.domain.config
import qs.domain.osd.events
import qs.domain.status
import qs.domain.status.icons

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

    // ---- what this shell reads for itself --------------------------------

    // Nothing is shown until the values have settled. A sink appearing and
    // powerdevil naming its displays both land as changes a second or so into
    // a session, and an OSD that greets every login with a volume bar nobody
    // asked for is worse than one that misses the first keypress.
    property bool _armed: false

    readonly property Timer _armTimer: Timer {
        interval: 1500
        running: root.enabled
        onTriggered: root._armed = true
    }

    function _raise(event) {
        if (root._armed && event)
            root._show(event);
    }

    // The last level actually reported, and the sink it belonged to.
    //
    // A volume property that changes is not the same as a volume that changed.
    // `AudioStatus.volume` reads through the default sink, and when that node
    // goes out from under it the value falls to zero and comes back -- two
    // changes, the second of which draws a pill showing the level nobody
    // touched. PipeWire's graph churns exactly that way while the taskbar
    // draws window previews: every preview is a screencast node appearing and
    // disappearing, and hovering along a row of buttons did it a hundred times
    // in three minutes, with "no global any more" in the journal for each one.
    //
    // So the level is remembered, and a repeat of it is not an event. A sink
    // that has gone is not one either: there is no level to report until it is
    // back, and what comes back is the same number as before.
    property real _lastVolume: -1
    property var _lastMuted: null
    property var _lastSink: null

    function _reportAudio(): void {
        const sink = AudioStatus.sink;

        // Nothing to report and nothing to remember: the value visible right
        // now is a placeholder, and recording it would make the real one that
        // follows look like a change.
        if (!sink)
            return;

        // A different output is a different thing to have a level at all. Its
        // first reading is where it stands, not a move to announce -- Plasma
        // says "output changed" for this, which is a different OSD entirely.
        if (sink !== root._lastSink) {
            root._lastSink = sink;
            root._lastVolume = AudioStatus.volume;
            root._lastMuted = AudioStatus.muted;
            return;
        }

        if (AudioStatus.volume === root._lastVolume && AudioStatus.muted === root._lastMuted)
            return;

        root._lastVolume = AudioStatus.volume;
        root._lastMuted = AudioStatus.muted;
        root._raise(OsdEvents.progress(StatusIcons.volumeIcon(AudioStatus.volume, AudioStatus.muted),
                                       AudioStatus.volume * 100, ""));
    }

    readonly property Connections _audio: Connections {
        target: root.enabled ? AudioStatus : null

        // Mute and level are one event, not two: the icon already says which
        // it was, and a bar that vanished on mute would hide the level the
        // next keypress is about to change.
        function onVolumeChanged(): void {
            root._reportAudio();
        }

        function onMutedChanged(): void {
            root._reportAudio();
        }

        // The microphone has no bar: what a person wants to know when they hit
        // that key is whether the room can hear them.
        function onMicMutedChanged(): void {
            root._raise(OsdEvents.message(StatusIcons.micIcon(AudioStatus.micVolume, AudioStatus.micMuted),
                                          AudioStatus.micMuted ? "Microphone muted" : "Microphone on"));
        }
    }

    // The lock keys, from the optional compiled module. Nothing on this
    // desktop announces them -- Plasma draws no OSD for a lock key and asks
    // for none -- so this is the only way the shell can know, and without the
    // module the Loader fails and the rest of the OSD is untouched.
    readonly property Loader _lockKeys: Loader {
        active: root.enabled
        source: Qt.resolvedUrl("../../platform/input/LockState.qml")

        onStatusChanged: {
            if (status === Loader.Error)
                Log.info("osd", "no lock-key OSD: the ShellInput module is not installed (make plugin)");
        }
    }

    readonly property Connections _locks: Connections {
        target: root._lockKeys.item

        function onCapsLockChanged(): void {
            root._raise(OsdEvents.message("input-caps-on",
                                          root._lockKeys.item.capsLock // qmllint disable missing-property
                                          ? "Caps Lock on" : "Caps Lock off"));
        }

        function onNumLockChanged(): void {
            root._raise(OsdEvents.message("input-num-on",
                                          root._lockKeys.item.numLock // qmllint disable missing-property
                                          ? "Num Lock on" : "Num Lock off"));
        }
    }

    readonly property Connections _brightness: Connections {
        target: root.enabled ? BrightnessStatus : null

        // The average across displays, which is what the panel's own icon
        // shows. Two monitors moved together are one change to report.
        function onLevelChanged(): void {
            if (BrightnessStatus.displays.length > 0)
                root._raise(OsdEvents.progress(StatusIcons.brightnessIcon(BrightnessStatus.level),
                                               BrightnessStatus.level * 100, ""));
        }
    }

    // A match rule rather than a whole-bus monitor: eavesdropping on
    // everything to catch two signals would put every message on the session
    // bus through this process, including other applications' payloads.
    //
    // Still here with the sources above in place, because it is the only way
    // this shell hears about the things it does not read: the keyboard layout,
    // the touchpad, caps lock. Where plasmashell does emit, a volume key
    // arrives twice -- once here, once from PipeWire -- and both carry the
    // same number, so the pill is redrawn identically rather than twice over.
    readonly property BusMonitor _monitor: BusMonitor {
        match: "type='signal',interface='org.kde.osdService'"
        running: root.enabled

        onRead: line => {
            const event = OsdEvents.parse(line);
            if (event)
                root._show(event);
        }

        onListeningChanged: {
            if (listening)
                Log.info("osd", "listening for Plasma's OSD signals");
            else if (root.enabled)
                Log.warn("osd", "the OSD listener stopped; nothing will be drawn");
        }
    }
}
