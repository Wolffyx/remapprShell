pragma ComponentBehavior: Bound

// What a taskbar button shows when the pointer rests on it.
//
// One layout, whatever the window count. It used to be two: a single window
// drew a large picture with the application's name *under* it and its title
// under that, and two or more drew a header with a grid beneath. So the same
// application read top-to-bottom in two different orders depending on how many
// windows it happened to have, the picture changed size when a second one
// opened, and an application whose window is titled after itself -- Claude,
// Steam, most single-window applications -- said its own name twice in a row.
//
// Now: the header says what the application is, once, and every window is a
// card below it. One window is a grid of one.
//
// A card says what the window is *for* rather than only what it is called. A
// title is often the application's own name again, and when it is, saying it
// under the header is noise; what is worth the line is where the window is --
// its desktop, and which monitor when there is more than one.

import QtQuick
import Quickshell
import qs.domain.desktops
import qs.domain.theme
import qs.domain.windows
import qs.domain.windows.events
import qs.ui.primitives

Item {
    id: root

    // The taskbar entry this stands for: its application name and icon.
    property var item: null

    // Its windows, in the order the taskbar keeps them. Empty for a pinned
    // application that is not running.
    property var windows: []

    // The pointer is on the card. The taskbar uses this to decide whether to
    // start closing it.
    property bool pointerInside: false

    // A window was chosen, so the card has done its job.
    signal picked

    readonly property bool many: root.windows.length > 1

    // Three across before it wraps. Four Chrome windows in a row is wider than
    // a laptop screen, and a card wider than the screen is clamped -- which
    // puts the cards under a button they did not come from.
    readonly property int columns: Math.min(3, Math.max(1, root.windows.length))

    // One size, whatever the window count. A picture of a window is there to
    // be recognised, and how many other windows the application happens to
    // have open says nothing about how big it needs to be to manage that.
    readonly property int cellWidth: 300
    readonly property int cellHeight: 169

    implicitWidth: Math.max(260, body.implicitWidth + 28)
    implicitHeight: body.implicitHeight + 28

    // Where a window is, said the way somebody looking for it would say it.
    //
    // Empty when there is nothing worth saying: one desktop and one monitor is
    // every ordinary machine, and "Desktop 1" under every card on such a
    // machine is a column of noise.
    function place(window) {
        if (!window)
            return "";
        const parts = [];

        if (Desktops.count > 1) {
            const ids = window.desktops ?? [];
            if (ids.length === 0) {
                parts.push("All desktops");
            } else {
                const desk = (Desktops.desktops ?? []).find(d => d.id === ids[0]);
                if (desk)
                    parts.push(desk.name || `Desktop ${desk.position + 1}`);
            }
        }

        if (window.output && Quickshell.screens.length > 1)
            parts.push(window.output);

        return parts.join(" · ");
    }

    // What a card's caption says. The title, unless the title is the
    // application's own name -- then the place, which is the thing the title
    // was failing to tell anybody.
    //
    // And nothing at all when neither says anything: one window of an
    // application titled after itself, on a machine with one desktop and one
    // monitor, has a header above it that already reads "Claude". A line
    // repeating it is the fault this redesign started from, and a blank line
    // held open for it is the same fault with the text removed.
    function caption(window) {
        const title = WindowEvents.label(window);
        const app = root.item?.appName ?? "";
        if (title.length > 0 && title !== app)
            return title;
        return root.place(window);
    }

    // The pointer being on the card is what keeps the card. Declared here
    // rather than on each cell so the gaps between them count as being on it
    // too.
    HoverHandler {
        id: cardHover
        onHoveredChanged: root.pointerInside = cardHover.hovered
    }

    // Closing a window from its own picture, as every taskbar preview does.
    //
    // Drawn faintly rather than only under the pointer. A cross nobody can see
    // is a feature nobody finds, and this one is small, in a corner, and on a
    // card that is already a deliberate hover; the risk it guards against is a
    // row of bright crosses over something somebody is only reading, which
    // dimming answers just as well.
    component CloseButton: Rectangle {
        id: closeButton

        required property string uuid

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        width: 20
        height: 20
        radius: 10
        opacity: closePointer.hovered ? 1 : 0.55
        color: closePointer.hovered ? Theme.error : Theme.alpha(Theme.background, 0.8)
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        Glyph {
            anchors.centerIn: parent
            name: "close"
            fallback: "window-close"
            size: 13
            color: closePointer.hovered ? Theme.errorFg : Theme.foreground
        }

        HoverHandler { id: closePointer; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            // The card stays: closing one of five windows is usually the first
            // of several, and a card that vanished would make the second a
            // fresh hunt. It closes itself when the last one goes, because the
            // group does.
            onTapped: WindowsService.close(closeButton.uuid)
        }
    }

    Column {
        id: body
        anchors.centerIn: parent
        spacing: 12

        // The application, once, at the top, however many windows it has.
        Row {
            spacing: 12

            PanelIcon {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 40
                iconName: root.item?.iconName ?? ""
                iconFile: root.item?.iconFile ?? ""
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                PanelText {
                    text: root.item?.appName ?? ""
                    font.bold: true
                }

                PanelText {
                    visible: text.length > 0
                    text: root.many ? `${root.windows.length} windows — pick one`
                        : root.windows.length === 0 ? "Pinned — click to start it"
                        : root.place(root.windows[0])
                    color: Theme.foregroundInactive
                    font.pixelSize: 11
                }
            }
        }

        // Every window it has, each with its own picture and each a target.
        // Only `columns` is set -- see ZoneRow for why setting both goes wrong.
        Grid {
            columns: root.columns
            spacing: 8

            Repeater {
                model: root.windows

                Rectangle {
                    id: cell

                    required property var modelData
                    required property int index

                    width: root.cellWidth
                    height: root.cellHeight + (cellTitle.visible ? cellTitle.implicitHeight + 4 : 0) + 10
                    radius: Theme.radiusOf(12)
                    // Every card has a surface of its own, resting. A
                    // transparent one left the picture floating with its close
                    // cross beside it in open space, and a grid of four read
                    // as four unrelated things rather than one application's
                    // windows.
                    color: cell.modelData.active ? Theme.accC
                         : cellPointer.hovered ? Theme.s2
                                               : Theme.alpha(Theme.foreground, 0.05)
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    WindowThumbnail {
                        id: shot
                        x: 4
                        y: 4
                        width: root.cellWidth - 8
                        height: root.cellHeight
                        windowId: cell.modelData.uuid ?? ""
                        iconName: root.item?.iconName ?? ""
                        iconFile: root.item?.iconFile ?? ""
                        iconScale: 0.4
                        sourceAspect: WindowEvents.aspectOf(cell.modelData)
                        // A picture is a screencast stream, and one per window
                        // is one per window. Eight is more than anybody picks
                        // from at a glance; past that the cards are icons,
                        // which is what a thumbnail falls back to anyway.
                        live: cell.index < 8
                        opacity: cell.modelData.minimized ? 0.55 : 1
                    }

                    PanelText {
                        id: cellTitle
                        x: 6
                        width: cell.width - 12
                        visible: text.length > 0
                        anchors.top: shot.bottom
                        anchors.topMargin: 4
                        elide: Text.ElideRight
                        text: root.caption(cell.modelData)
                        color: cell.modelData.minimized ? Theme.foregroundInactive : Theme.foreground
                        font.pixelSize: 11
                        font.italic: cell.modelData.minimized
                    }

                    CloseButton { uuid: cell.modelData.uuid ?? "" }

                    HoverHandler { id: cellPointer; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        // The whole cell, not the picture: a target the size of
                        // the thing it stands for.
                        onTapped: {
                            WindowsService.activate(cell.modelData.uuid);
                            root.picked();
                        }
                    }
                }
            }
        }
    }
}
