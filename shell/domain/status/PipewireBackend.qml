// The default output and input, read from PipeWire and written back to it.
//
// PipeWire owns the volume; this is a view of it with a few verbs. A node's
// audio properties are only live while something tracks the node, so the
// tracker lives here, once, rather than in every copy of the widget -- one per
// screen would work, and would say the same thing twice.
//
// One of AudioStatus's two readers; PulseBackend is the other, with the same
// properties and verbs.

import QtQuick
import Quickshell.Services.Pipewire

QtObject {
    id: root

    // Whether AudioStatus is reading this one. Nothing is tracked otherwise.
    property bool active: false

    readonly property bool ready: Pipewire.ready

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property real volume: root.sink?.audio?.volume ?? 0
    readonly property bool muted: root.sink?.audio?.muted ?? false
    readonly property real micVolume: root.source?.audio?.volume ?? 0
    readonly property bool micMuted: root.source?.audio?.muted ?? false

    // Devices to play through, and to record from: hardware nodes, not the
    // streams applications open on them.
    readonly property var sinks: (Pipewire.nodes?.values ?? [])
        .filter(n => n && n.isSink && !n.isStream && n.audio)
    readonly property var sources: (Pipewire.nodes?.values ?? [])
        .filter(n => n && !n.isSink && !n.isStream && n.audio)

    function setVolume(value) {
        if (root.sink?.audio)
            root.sink.audio.volume = Math.max(0, value);
    }

    function toggleMute() {
        if (root.sink?.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    function setMicVolume(value) {
        if (root.source?.audio)
            root.source.audio.volume = Math.max(0, value);
    }

    function toggleMicMute() {
        if (root.source?.audio)
            root.source.audio.muted = !root.source.audio.muted;
    }

    // Asks for a different default. WirePlumber decides, and remembers it,
    // exactly as it would for the same choice made in Plasma's applet.
    function useSink(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function useSource(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    readonly property PwObjectTracker _tracker: PwObjectTracker {
        objects: root.active ? [root.sink, root.source].filter(n => !!n) : []
    }
}
