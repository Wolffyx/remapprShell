pragma Singleton

// The default output and input, read from PipeWire and written back to it.
//
// PipeWire owns the volume; this is a view of it with a few verbs. A node's
// audio properties are only live while something tracks the node, so the
// tracker lives here, once, rather than in every copy of the widget -- one per
// screen would work, and would say the same thing twice.

import QtQuick
import Quickshell.Services.Pipewire
import qs.domain.config
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

    // Devices to play through, and to record from: hardware nodes, not the
    // streams applications open on them.
    readonly property var sinks: (Pipewire.nodes?.values ?? [])
        .filter(n => n && n.isSink && !n.isStream && n.audio)
    readonly property var sources: (Pipewire.nodes?.values ?? [])
        .filter(n => n && !n.isSink && !n.isStream && n.audio)

    // How far a volume slider goes. PipeWire will happily amplify past 1.0 and
    // distort doing it, so the ceiling is 100% until someone asks for the
    // headroom -- the same choice, under the same name, as Plasma's applet.
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
            inputs: root.sources.map(n => root.nameOf(n)),
            maxVolume: root.maxVolume,
            icon: root.icon
        };
    }

    readonly property PwObjectTracker _tracker: PwObjectTracker {
        objects: [root.sink, root.source].filter(n => !!n)
    }
}
