pragma ComponentBehavior: Bound

// A picture of a window, or the application's icon when there is no picture.
//
// Everything that shows a window -- the taskbar's hover preview, the desktop
// overview, this shell's own switcher -- wants the same thing and the same
// fallback, so it lives here once.
//
// The picture needs `KWinScreencast` (plugin/, this project's only compiled
// part) and kpipewire, and the compositor has to agree: KWin advertises the
// screencast protocol only to a client whose desktop file names it, which
// ours does. Any of those missing means the icon, which is why the stream is
// reached through a Loader by file name rather than imported: a missing QML
// module is an error in one small file instead of a shell that will not start.

import QtQuick
import qs.core

Item {
    id: root

    // KWin's uuid for the window, and the icon to draw when there is no
    // stream. Both come straight off a window in the window list.
    property string windowId: ""
    property string iconName: ""
    property string iconFile: ""

    // What shape the window is, for letterboxing the feed.
    property real sourceAspect: 16 / 9

    // How big the icon is drawn when it stands in for the picture.
    property real iconScale: 0.42

    // Whether this thumbnail wants a live picture. Off means the icon, and
    // means the compositor is asked for nothing at all.
    property bool live: true

    // Whether a picture is actually being drawn, for a caller that wants to
    // say so -- or to stop drawing its own title over it.
    readonly property bool showingPicture: root.live && (stream.item?.showing ?? false)

    // Said once per session rather than per thumbnail: a shell with no plugin
    // is a shell showing icons, and that should be explicable without reading
    // the source.
    property bool _complained: false

    // The icon sits *under* the picture rather than being swapped out for it.
    //
    // A stream can arrive and then draw nothing -- a fullscreen game whose
    // buffer kpipewire cannot turn into an EGL image logs
    // "invalid image EGL_BAD_PARAMETER" and shows a transparent item -- and a
    // card that is empty is worse than a card that is an icon. Underneath, the
    // icon is covered when there is a picture and shows through when there is
    // not, without anything having to detect which.
    PanelIcon {
        anchors.centerIn: parent
        implicitSize: Math.max(16, Math.round(Math.min(root.width, root.height) * root.iconScale))
        iconName: root.iconName
        iconFile: root.iconFile
    }

    Loader {
        id: stream

        anchors.fill: parent
        active: root.live && root.windowId.length > 0
        asynchronous: true
        source: Qt.resolvedUrl("../../platform/screencast/StreamSurface.qml")

        onStatusChanged: {
            if (stream.status !== Loader.Error || root._complained)
                return;
            root._complained = true;
            Log.info("screencast", "no window previews: the KWinScreencast module is not installed "
                                   + "(build it with `make plugin`); drawing icons instead");
        }

        onLoaded: {
            stream.item.windowId = Qt.binding(() => root.windowId);
            stream.item.active = Qt.binding(() => root.live);
            stream.item.sourceAspect = Qt.binding(() => root.sourceAspect);
        }
    }
}
