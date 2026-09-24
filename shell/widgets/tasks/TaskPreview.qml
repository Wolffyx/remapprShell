pragma ComponentBehavior: Bound

// What a taskbar button shows when the pointer rests on it.
//
// A card per window: a line with the application's small icon, the window's
// title and a close button, and the picture of the window under it -- the
// arrangement Windows uses, drawn in this shell's own surfaces and radii
// rather than copied from it. The card is the window -- its title is on it,
// its close button is on it, and clicking anywhere on it goes to it -- so
// nothing above the cards has to say what they are.
//
// The header this used to open with (a 40px icon, the application's name,
// "3 windows -- pick one") said once what every card now says for itself, and
// took a third of the height to do it. It is still there for anyone who wants
// it (`widgets.tasks.previewHeader`), smaller; it is off by default.
//
// Each picture is as wide as its window's shape needs at one shared height,
// rather than letterboxed into one box for every window. A tall window in a
// wide box was mostly empty card -- the margin that made a single preview
// look padded out -- and a row of windows that are all wide still lines up,
// because they are all the same height.

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

    // A window was chosen, so the card has done its job.
    signal picked

    // The application's name above the cards (`previewHeader`). Off, the
    // cards say it for themselves.
    property bool showHeader: false

    // The monitor a window is on, beside its title (`previewScreen`). Off by
    // default: a connector name like "DP-2" means something to whoever wired
    // the machine and nothing to anybody reading a title.
    property bool showScreen: false

    // Three across before it wraps. Four Chrome windows in a row is wider than
    // a laptop screen, and a card wider than the screen is clamped -- which
    // puts the cards under a button they did not come from.
    readonly property int perRow: 3

    // The picture's height, shared by every card; the width follows the
    // window, between a floor that still fits a title and a ceiling that keeps
    // an ultrawide window from taking the row.
    readonly property int shotHeight: 132
    readonly property int shotMin: 190
    readonly property int shotMax: 250
    readonly property int pad: 6
    readonly property int titleHeight: 24
    readonly property int gap: 6

    function shotWidth(window) {
        const w = Math.round(root.shotHeight * WindowEvents.aspectOf(window));
        return Math.max(root.shotMin, Math.min(root.shotMax, w));
    }

    function cardWidth(window) {
        return root.shotWidth(window) + 2 * root.pad;
    }

    // A card's window: the one at its place, which is where it is once the
    // list has settled, as long as the uuid agrees -- and found by uuid while
    // the list is still moving under it. The cards are repeated over the
    // uuids (see below), so this is how each reads what it shows.
    function windowFor(index, uuid) {
        const at = root.windows[index];
        return at?.uuid === uuid ? at : (root.windows.find(w => w.uuid === uuid) ?? root.noWindow);
    }

    // What a card on its way out reads, for the moment between its window
    // leaving the list and the card going.
    readonly property var noWindow: ({ uuid: "", title: "", appId: "", active: false, minimized: false,
                                       desktops: [], output: "", width: 0, height: 0 })

    // The widest row, so the Flow wraps after `perRow` cards and not earlier.
    readonly property int rowsWidth: {
        let widest = 0;
        for (let i = 0; i < root.windows.length; i += root.perRow) {
            const row = root.windows.slice(i, i + root.perRow);
            const w = row.reduce((sum, win) => sum + root.cardWidth(win), 0) + root.gap * (row.length - 1);
            widest = Math.max(widest, w);
        }
        return widest;
    }

    implicitWidth: Math.max(root.windows.length === 0 ? 220 : 0, body.implicitWidth) + 2 * root.pad
    implicitHeight: body.implicitHeight + 2 * root.pad

    // Where a window is, said the way somebody looking for it would say it --
    // beside the title, dimmer. Empty on one desktop and one monitor, which is
    // every ordinary machine.
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

        if (root.showScreen && window.output && Quickshell.screens.length > 1)
            parts.push(window.output);

        return parts.join(" · ");
    }

    // Closing a window from its own card: a round button at the end of the
    // title line, in the shell's error colour under the pointer. It is on the
    // title line rather than over the corner of the picture, where the old
    // one sat on top of the window's own content and was easy to miss. Shown
    // while the pointer is on the card; the middle button closes it too.
    component CloseButton: Rectangle {
        id: closeButton

        required property string uuid
        property bool shown: false

        width: root.titleHeight
        height: root.titleHeight
        radius: width / 2
        color: closePointer.hovered ? Theme.error : Theme.alpha(Theme.foreground, 0.08)
        opacity: closeButton.shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Glyph {
            anchors.centerIn: parent
            name: "close"
            fallback: "window-close"
            size: 15
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
        Accessible.role: Accessible.Button
        Accessible.name: "Close window"
    }

    Column {
        id: body
        x: root.pad
        y: root.pad
        spacing: root.gap

        // The application, once -- only when asked for, or when there is no
        // window to put a card for and the name is all there is to say.
        Row {
            visible: root.showHeader || root.windows.length === 0
            leftPadding: 4
            spacing: 8

            PanelIcon {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 20
                iconName: root.item?.iconName ?? ""
                iconFile: root.item?.iconFile ?? ""
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.item?.appName ?? ""
                font.bold: true
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                visible: text.length > 0
                text: root.windows.length > 1 ? `${root.windows.length} windows`
                    : root.windows.length === 0 ? "Pinned — click to start it"
                    : ""
                color: Theme.foregroundInactive
                font.pixelSize: 11
            }
        }

        Flow {
            width: root.rowsWidth
            spacing: root.gap
            visible: root.windows.length > 0

            Repeater {
                // Over the windows' uuids, not the windows. The list is made
                // afresh on every push from the window daemon, and a Repeater
                // over it built every card again each time -- and the live
                // picture in each, a screencast stream restarted for a title
                // changing anywhere. Over the uuids a card lives as long as
                // its window, and reads it through windowFor.
                model: ScriptModel { values: root.windows.map(w => w.uuid ?? "") }

                Rectangle {
                    id: cell

                    // The window's uuid, and its place among the cards.
                    required property string modelData
                    required property int index
                    readonly property var window: root.windowFor(cell.index, cell.modelData)

                    readonly property string where: root.place(cell.window)

                    width: root.cardWidth(cell.window)
                    height: root.pad + root.titleHeight + root.pad + root.shotHeight + root.pad
                    radius: Theme.radiusOf(12)
                    // Every card has a surface of its own, resting: without one
                    // the picture floats with its close button beside it in
                    // open space, and a grid of four reads as four unrelated
                    // things rather than one application's windows. The focused
                    // window is the accent's container, as its taskbar button
                    // is.
                    color: cell.window.active ? Theme.accC
                         : cellPointer.hovered ? Theme.s2
                                               : Theme.alpha(Theme.foreground, 0.05)
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    // --- the title line ---

                    PanelIcon {
                        id: cellIcon
                        x: root.pad + 2
                        y: root.pad + (root.titleHeight - height) / 2
                        implicitSize: 16
                        iconName: root.item?.iconName ?? ""
                        iconFile: root.item?.iconFile ?? ""
                    }

                    PanelText {
                        id: cellTitle
                        anchors.left: cellIcon.right
                        anchors.leftMargin: 8
                        anchors.right: close.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: cellIcon.verticalCenter
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        // The title, and where the window is when that is worth
                        // saying, dimmer after it.
                        text: {
                            const title = WindowEvents.label(cell.window) || (root.item?.appName ?? "");
                            const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
                            return cell.where.length > 0
                                ? `${esc(title)} <font color="${Theme.foregroundInactive}">· ${esc(cell.where)}</font>`
                                : esc(title);
                        }
                        color: cell.window.active ? Theme.accCFg
                             : cell.window.minimized ? Theme.foregroundInactive : Theme.foreground
                        font.pixelSize: 12
                        font.italic: cell.window.minimized
                    }

                    CloseButton {
                        id: close
                        x: cell.width - width - root.pad
                        y: root.pad
                        uuid: cell.window.uuid ?? ""
                        shown: cellPointer.hovered
                    }

                    // --- the picture ---

                    WindowThumbnail {
                        id: shot
                        x: root.pad
                        y: root.pad + root.titleHeight + root.pad
                        width: cell.width - 2 * root.pad
                        height: root.shotHeight
                        windowId: cell.window.uuid ?? ""
                        iconName: root.item?.iconName ?? ""
                        iconFile: root.item?.iconFile ?? ""
                        iconScale: 0.4
                        sourceAspect: WindowEvents.aspectOf(cell.window)
                        // A picture is a screencast stream, and one per window
                        // is one per window. Eight is more than anybody picks
                        // from at a glance; past that the cards are icons,
                        // which is what a thumbnail falls back to anyway.
                        live: cell.index < 8
                        opacity: cell.window.minimized ? 0.55 : 1
                    }

                    HoverHandler { id: cellPointer; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        // The whole card, not the picture: a target the size of
                        // the thing it stands for.
                        onTapped: {
                            WindowsService.activate(cell.window.uuid);
                            root.picked();
                        }
                    }
                    TapHandler {
                        // The wheel pressed on a card closes that window, as
                        // it does on Windows' previews. The card stays, as it
                        // does for the close button, and goes with the last.
                        acceptedButtons: Qt.MiddleButton
                        onTapped: WindowsService.close(cell.window.uuid)
                    }
                }
            }
        }
    }
}
