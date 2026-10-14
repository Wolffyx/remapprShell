// The default output and input, read from a PulseAudio server with pactl and
// written back to it the same way.
//
// One of AudioStatus's two readers, for when the PulseAudio socket is
// PulseAudio's own (PactlState says why that matters). Its shape is
// PipewireBackend's: the same properties, the same verbs, and devices that are
// objects -- one per device for as long as it is there, so a widget can tell
// the current one by identity, as it does a PipeWire node. Nothing runs while
// it is not the one being read.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.status.audio

QtObject {
    id: root

    // Whether AudioStatus is reading this one.
    property bool active: false

    // The server stopped answering: whoever chose this reader should ask
    // again who is.
    signal lost()

    property bool ready: false
    property var sinks: []
    property var sources: []
    property var sink: null
    property var source: null
    property real volume: 0
    property bool muted: false
    property real micVolume: 0
    property bool micMuted: false

    // The level is drawn where it was asked for at once; the server's word on
    // it follows (see `_read`).
    function setVolume(value) {
        if (!root.sink)
            return;
        root.volume = Math.max(0, value);
        root._send("sink-volume", ["set-sink-volume", root.sink.name, PactlState.volumeArg(value)]);
    }

    // Set, not toggled: two presses queued behind a slow write must land
    // where the second one says, not back where they started.
    function toggleMute() {
        if (!root.sink)
            return;
        root.muted = !root.muted;
        root._send("sink-mute", ["set-sink-mute", root.sink.name, root.muted ? "1" : "0"]);
    }

    function setMicVolume(value) {
        if (!root.source)
            return;
        root.micVolume = Math.max(0, value);
        root._send("source-volume", ["set-source-volume", root.source.name, PactlState.volumeArg(value)]);
    }

    function toggleMicMute() {
        if (!root.source)
            return;
        root.micMuted = !root.micMuted;
        root._send("source-mute", ["set-source-mute", root.source.name, root.micMuted ? "1" : "0"]);
    }

    // The server moves what is playing to the new default and remembers it,
    // as it does for the same choice made in Plasma's applet.
    function useSink(node) {
        if (node)
            root._send("default-sink", ["set-default-sink", node.name]);
    }

    function useSource(node) {
        if (node)
            root._send("default-source", ["set-default-source", node.name]);
    }

    // ---- the devices -----------------------------------------------------------

    // name -> its object, kept across reads: a device read twice is the same
    // object both times, or "the current one" would change on every read.
    property var _nodes: ({})

    readonly property Component _node: Component {
        QtObject {
            property string name
            property string description
        }
    }

    function _nodeFor(device) {
        let node = root._nodes[device.name];
        if (!node) {
            node = root._node.createObject(root, { name: device.name });
            root._nodes[device.name] = node;
        }
        node.description = device.description;
        return node;
    }

    function _apply(state) {
        if (!state) {
            root._clear();
            return;
        }
        const seen = ({});
        const sinks = state.sinks.map(d => {
            seen[d.name] = true;
            return root._nodeFor(d);
        });
        const sources = state.sources.map(d => {
            seen[d.name] = true;
            return root._nodeFor(d);
        });
        const sink = state.sinks.find(d => d.name === state.defaultSink) ?? null;
        const source = state.sources.find(d => d.name === state.defaultSource) ?? null;

        root.sinks = sinks;
        root.sources = sources;
        root.sink = sink ? root._nodes[sink.name] : null;
        root.source = source ? root._nodes[source.name] : null;
        root.volume = sink?.volume ?? 0;
        root.muted = sink?.muted ?? false;
        root.micVolume = source?.volume ?? 0;
        root.micMuted = source?.muted ?? false;
        root.ready = true;

        // Only now, with nothing above pointing at them any more.
        for (const name of Object.keys(root._nodes).filter(n => !seen[n]))
            root._drop(name);
    }

    function _drop(name) {
        root._nodes[name].destroy();
        delete root._nodes[name];
    }

    function _clear() {
        root.ready = false;
        root.sinks = [];
        root.sources = [];
        root.sink = null;
        root.source = null;
        root.volume = 0;
        root.muted = false;
        root.micVolume = 0;
        root.micMuted = false;
        for (const name of Object.keys(root._nodes))
            root._drop(name);
    }

    // ---- reading ---------------------------------------------------------------

    property bool _again: false

    readonly property Process _read: Process {
        id: reader
        // Never cut short: one asked for meanwhile follows it instead.
        onRunningChanged: {
            if (!running && root._again && root.active) {
                root._again = false;
                running = true;
            }
        }
        // pactl's JSON ends without a newline, so each is followed by one:
        // without it the next section's name is the end of the last JSON line.
        command: ["sh", "-c",
            "echo @info; pactl -f json info; echo; "
            + "echo @sinks; pactl -f json list sinks; echo; "
            + "echo @sources; pactl -f json list sources; echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active)
                    return;
                // A level read while a change of ours is on its way is the
                // level before it -- a slider being dragged would jump back
                // to it. The read after the last write says where it landed.
                if (writer.running || root._queue.length > 0)
                    return;
                root._apply(PactlState.parse(text));
            }
        }
    }

    // Events come in bursts -- a default changing is a sink, a source and the
    // server -- so a read waits for the burst to end.
    readonly property Timer _settle: Timer {
        id: settle
        interval: 80
        onTriggered: {
            if (reader.running)
                root._again = true;
            else
                reader.running = true;
        }
    }

    property bool _warned: false

    readonly property Process _events: Process {
        id: events
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: line => {
                if (PactlState.relevant(line))
                    settle.restart();
            }
        }
        // pactl subscribe only ends when the server does.
        onExited: code => {
            if (!root.active)
                return;
            if (!root._warned)
                Log.warn("audio", `the PulseAudio server stopped answering (pactl subscribe exit ${code})`);
            root._warned = true;
            root._clear();
            root.lost();
            retry.start();
        }
    }

    readonly property Timer _retry: Timer {
        id: retry
        interval: 3000
        onTriggered: root._start()
    }

    // ---- writing ---------------------------------------------------------------

    // What is still to be sent, one per kind of change: a slider dragged
    // faster than pactl starts would otherwise queue every step it passed.
    property var _queue: []

    function _send(key, args) {
        const queue = root._queue.filter(c => c.key !== key);
        queue.push({ key: key, args: args });
        root._queue = queue;
        if (!writer.running)
            root._next();
    }

    function _next() {
        const change = root._queue[0];
        if (!change) {
            settle.restart();
            return;
        }
        root._queue = root._queue.slice(1);
        writer.command = ["pactl"].concat(change.args);
        writer.running = true;
    }

    readonly property Process _write: Process {
        id: writer
        onExited: code => {
            if (code !== 0)
                Log.warn("audio", `pactl ${writer.command[1]} failed (exit ${code})`);
            Qt.callLater(root._next);
        }
    }

    // ---- running ---------------------------------------------------------------

    function _start() {
        if (!root.active)
            return;
        events.running = true;
        settle.restart();
    }

    function _stop() {
        retry.stop();
        settle.stop();
        events.running = false;
        root._queue = [];
        root._again = false;
        root._warned = false;
        root._clear();
    }

    onActiveChanged: {
        if (root.active) {
            root._start();
            return;
        }
        root._stop();
    }

    // A read that answers resets the warning, so the next loss is said too.
    onReadyChanged: {
        if (root.ready)
            root._warned = false;
    }

    Component.onCompleted: root._start()
}
