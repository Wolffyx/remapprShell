pragma Singleton

// Which applications have the camera or a microphone, as PipeWire sees it.
//
// Plasma shows this with an icon in its system tray: the microphone one comes
// from the volume applet's own plugin (MicrophoneIndicator, in
// libplasma-volume-declarative, which nothing else loads), and the camera one
// is an applet of its own. Under our renderer there is no tray of Plasma's, so
// nothing said it -- a browser tab could be listening with nothing on screen.
//
// The rule is StatusIcons.recorders; this only describes PipeWire's links to
// it. Three things about Quickshell 0.3 decide how, each found by running it:
//   - A node's properties (media class, application) arrive only while the
//     node is tracked -- and only when it is tracked as an element of
//     `Pipewire.nodes`. Tracking the same node reached through a link bound
//     nothing.
//   - `PwLinkGroup.state` stays "unlinked" whatever is tracked. A PwLink's
//     own state is live once the links are tracked, so links it is: one per
//     port, two for a stereo stream, and the rule drops the repeats.
//   - A bound stream's `description` is empty; the application name is in
//     its properties, and failing that in the node's name.

import QtQuick
import Quickshell.Services.Pipewire
import qs.domain.status.icons

QtObject {
    id: root

    // Real arrays, not the models' `values`: those are Qt sequences, whose
    // `filter` hands back another sequence without `flatMap` or `concat`.
    readonly property var nodes: Array.from(Pipewire.nodes?.values ?? []).filter(n => !!n)
    readonly property var links: Array.from(Pipewire.links?.values ?? []).filter(l => !!l)

    // { microphone: [app], camera: [app] }
    readonly property var users: StatusIcons.recorders(root.links.map(l => ({
        active: l.state === PwLinkState.Active,
        source: root._describe(l.source),
        target: root._describe(l.target)
    })))

    readonly property bool present: root.users.microphone.length > 0 || root.users.camera.length > 0

    // Every link as the rule is handed it, so a wrong answer can be told
    // apart from wrong input. Media classes and application names only.
    function summary() {
        return {
            ready: Pipewire.ready,
            bound: root.nodes.filter(n => n.ready).length,
            microphone: root.users.microphone,
            camera: root.users.camera,
            links: root.links.map(l => ({
                state: PwLinkState.toString(l.state),
                from: root._describe(l.source),
                to: root._describe(l.target)
            }))
        };
    }

    function _describe(node) {
        const p = node?.properties ?? {};
        return {
            mediaClass: p["media.class"] ?? "",
            api: p["device.api"] ?? "",
            role: p["media.role"] ?? "",
            app: p["application.name"] || node?.name || node?.description || ""
        };
    }

    readonly property PwObjectTracker _tracker: PwObjectTracker {
        objects: root.nodes.concat(root.links)
    }
}
