// The installer's window: a view, sized to what it shows.
//
// As tall as the page in hand wants, between a floor that keeps the buttons
// where they were and nine tenths of the screen -- past that the page
// scrolls inside the window. kdialog's fixed-size boxes cut the same choices
// off mid-sentence; this is why the installer has a window of its own.

import QtQuick
import Quickshell
import qs.core
import qs.domain.theme

FloatingWindow {
    id: root

    signal done

    title: `Install ${Branding.displayName}`
    color: Theme.background

    readonly property real screenHeight: root.screen ? root.screen.height : 1000

    implicitWidth: 760
    implicitHeight: Math.round(Math.min(root.screenHeight * 0.9, Math.max(560, view.wantedHeight)))

    InstallerView {
        id: view
        anchors.fill: parent
        onCloseRequested: root.done()
    }
}
