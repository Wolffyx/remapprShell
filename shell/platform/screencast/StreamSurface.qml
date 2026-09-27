// A window's live picture, where the compositor will give one.
//
// Two things outside this project make it possible, and both are optional:
// `KWinScreencast`, this project's one compiled part (see plugin/), which
// turns a window's uuid into a PipeWire node id; and `org.kde.pipewire`, from
// kpipewire, which draws a node.
//
// Loaded by name rather than imported directly by anything that draws -- see
// ui/primitives/WindowThumbnail.qml -- so a shell without the plugin, or
// without kpipewire, draws the application's icon instead of failing to start.
// That is why this file is small: everything that can be missing is in it.

import QtQuick
import qs.core
import org.kde.pipewire as PipeWire
import KWinScreencast

Item {
    id: root

    // KWin's uuid for the window, as the window list reports it.
    property string windowId: ""

    // Whether this wants pixels at all. A stream costs the compositor a
    // capture, so a thumbnail nobody is looking at turns its own off.
    property bool active: true

    // What the window's own shape is, so the feed can be letterboxed: a
    // PipeWireSourceItem fills whatever it is given, and a 16:9 window
    // stretched into a square card is a worse picture than no picture.
    property real sourceAspect: 16 / 9

    readonly property bool showing: stream.available
    readonly property string error: stream.error

    WindowStream {
        id: stream
        windowId: root.windowId
        active: root.active

        // Which window got a node, and which did not. Debug rather than info:
        // a shell with a preview open asks for one of these a second.
        onNodeIdChanged: Log.debug("screencast", `${root.windowId}: node ${stream.nodeId}`)
        onErrorChanged: if (stream.error)
            Log.warn("screencast", `${root.windowId}: ${stream.error}`)
    }

    PipeWire.PipeWireSourceItem {
        readonly property real fitted: root.sourceAspect > (root.width / Math.max(1, root.height))
            ? root.width / root.sourceAspect
            : root.height

        anchors.centerIn: parent
        width: fitted * root.sourceAspect
        height: fitted

        // Only ever a node that exists.
        //
        // `WindowStream.nodeId` is -1 while there is no stream -- before the
        // compositor answers, and again the moment it closes -- because that
        // is how QML asks "is there one". kpipewire's own `nodeId` is
        // *unsigned*, so binding the two together handed it 4294967295 on
        // every teardown, and it connected to that: "created successfully
        // 4294967295", a format that makes no sense, and `invalid image
        // "EGL_BAD_PARAMETER"` for the frame that followed. Hovering along a
        // row of taskbar buttons did it a hundred and fifty times, because
        // every preview closing is one of these.
        nodeId: stream.available ? stream.nodeId : 0
        visible: stream.available
    }
}
