// Launchpad, offscreen, over a plain background: the first page of what is
// installed on this machine. PREVIEW_QUERY types into it.
//
//   dev/preview/preview.sh dev/preview/launchpad.qml out.png 1600 1000 dark

import QtQuick
import Quickshell
import qs.domain.theme
import qs.features.launcher

Rectangle {
    color: Theme.dark ? "#1d2b3a" : "#9fb4c8"

    // Something busy behind it, to see how much shows through.
    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: "file:///usr/share/wallpapers/cachyos-wallpapers/Abstract.png"
    }

    LaunchpadOverlay {
        anchors.fill: parent
        Component.onCompleted: query = Quickshell.env("PREVIEW_QUERY") || ""
    }
}
