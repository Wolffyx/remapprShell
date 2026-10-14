pragma Singleton

// The default output and input, and the devices to choose between, from
// whichever sound server is answering.
//
// PipeWire is read directly (PipewireBackend). Where the PulseAudio socket is
// answered by PulseAudio itself, the devices are PulseAudio's and PipeWire
// never sees them, so that server is read through pactl instead
// (PulseBackend; PactlState says how that was found out). Which one is the
// `audio.backend` setting, and "auto" asks the socket who is answering.
// Either way the widgets see one shape: the properties and verbs below, and
// devices told apart by identity.

import QtQuick
import Quickshell.Io
import qs.domain.config
import qs.domain.status.audio
import qs.domain.status.icons

QtObject {
    id: root

    readonly property string choice: ConfigStore.value("audio.backend", "auto")

    // Who answers the PulseAudio socket, by the name it gives itself:
    // "pulseaudio", "PulseAudio (on PipeWire 1.6.9)", or "" for nobody -- or
    // not asked yet, which reads PipeWire until the answer comes.
    property string server: ""

    readonly property string backend: PactlState.backendFor(root.choice, root.server)
    readonly property var _impl: root.backend === "pulse" ? pulse : pipewire

    readonly property bool ready: root._impl.ready
    readonly property var sink: root._impl.sink
    readonly property var source: root._impl.source

    readonly property real volume: root._impl.volume
    readonly property bool muted: root._impl.muted
    readonly property real micVolume: root._impl.micVolume
    readonly property bool micMuted: root._impl.micMuted

    readonly property string icon: StatusIcons.volumeIcon(root.volume, root.muted)
    readonly property string glyph: StatusIcons.volumeGlyph(root.volume, root.muted)

    // Devices to play through, and to record from: hardware, not the streams
    // applications open on it.
    readonly property var sinks: root._impl.sinks
    readonly property var sources: root._impl.sources

    // How far a volume slider goes. Either server will happily amplify past
    // 1.0 and distort doing it, so the ceiling is 100% until someone asks for
    // the headroom -- the same choice, under the same name, as Plasma's applet.
    //
    // A level already above the ceiling raises it rather than being dragged
    // down by the control drawn for it: something else set that, and a slider
    // is not the place to find out.
    readonly property bool raiseMax: ConfigStore.value("audio.raiseMaxVolume", false) === true
    readonly property real maxVolume: root.raiseMax ? 1.5 : 1
    function ceilingFor(value) {
        return Math.max(root.maxVolume, value);
    }

    function nameOf(node) {
        return node?.description || node?.nickname || node?.name || "";
    }

    function setVolume(value) {
        root._impl.setVolume(value);
    }

    function toggleMute() {
        root._impl.toggleMute();
    }

    function setMicVolume(value) {
        root._impl.setMicVolume(value);
    }

    function toggleMicMute() {
        root._impl.toggleMicMute();
    }

    // Asks for a different default. The server decides, and remembers it,
    // exactly as it would for the same choice made in Plasma's applet.
    function useSink(node) {
        root._impl.useSink(node);
    }

    function useSource(node) {
        root._impl.useSource(node);
    }

    // Who is answering the socket. Asked at start, when the PulseAudio reader
    // loses its server, and now and then while the setting leaves it to us:
    // a package install can swap one server for the other under a running
    // session, and that is exactly when the picker must not go quiet.
    function probe() {
        if (!asker.running)
            asker.running = true;
    }

    function summary() {
        return {
            ready: root.ready,
            backend: root.backend,
            server: root.server,
            output: root.nameOf(root.sink),
            volume: root.volume,
            muted: root.muted,
            input: root.nameOf(root.source),
            micVolume: root.micVolume,
            micMuted: root.micMuted,
            outputs: root.sinks.map(n => root.nameOf(n)),
            inputs: root.sources.map(n => root.nameOf(n)),
            maxVolume: root.maxVolume,
            icon: root.icon
        };
    }

    readonly property PipewireBackend _pipewire: PipewireBackend {
        id: pipewire
        active: root.backend === "pipewire"
    }

    readonly property PulseBackend _pulse: PulseBackend {
        id: pulse
        active: root.backend === "pulse"
        onLost: root.probe()
    }

    readonly property Process _asker: Process {
        id: asker
        command: ["pactl", "-f", "json", "info"]
        stdout: StdioCollector {
            onStreamFinished: root.server = PactlState.serverName(text)
        }
    }

    readonly property Timer _poll: Timer {
        interval: 60000
        repeat: true
        running: root.choice === "auto"
        onTriggered: root.probe()
    }

    Component.onCompleted: root.probe()
}
