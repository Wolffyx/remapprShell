pragma Singleton

// The default output and input, read from PipeWire and written back to it.
//
// PipeWire owns the volume; this is a view of it with a few verbs. A node's
// audio properties are only live while something tracks the node, so the
// tracker lives here, once, rather than in every copy of the widget -- one per
// screen would work, and would say the same thing twice.

import QtQuick
import Quickshell.Services.Pipewire
import qs.domain.status.icons

QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property real volume: root.sink?.audio?.volume ?? 0
    readonly property bool muted: root.sink?.audio?.muted ?? false
    readonly property real micVolume: root.source?.audio?.volume ?? 0
    readonly property bool micMuted: root.source?.audio?.muted ?? false

    readonly property string icon: StatusIcons.volumeIcon(root.volume, root.muted)
    readonly property string glyph: StatusIcons.volumeGlyph(root.volume, root.muted)

    // Devices to play through: hardware outputs, not applications' streams.
    readonly property var sinks: (Pipewire.nodes?.values ?? [])
        .filter(n => n && n.isSink && !n.isStream && n.audio)

    function nameOf(node) {
        return node?.description || node?.nickname || node?.name || "";
    }

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

    function summary() {
        return {
            ready: Pipewire.ready,
            output: root.nameOf(root.sink),
            volume: root.volume,
            muted: root.muted,
            input: root.nameOf(root.source),
            micVolume: root.micVolume,
            micMuted: root.micMuted,
            outputs: root.sinks.map(n => root.nameOf(n)),
            icon: root.icon
        };
    }

    readonly property PwObjectTracker _tracker: PwObjectTracker {
        objects: [root.sink, root.source].filter(n => !!n)
    }
}
