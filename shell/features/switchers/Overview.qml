pragma ComponentBehavior: Bound

// Meta+Tab: the desktops, and what is open on each.
//
// KWin's own Overview is the other choice and cannot be restyled -- it is
// compiled into KWin rather than shipped as a package -- so this is the one
// that can look like the rest of the shell. `switching.desktops` picks, and
// the key follows whichever draws it (see scripts/switcher.sh).
//
// The design's Super+Tab view, in three parts: a header saying how many
// desktops there are and what the keys do, the windows of the desktop under
// the selection drawn large, and a strip along the bottom with every desktop
// and a glance at what is on it.
//
// Held, like the window switcher: another press of the key steps to the next
// desktop, and letting the key go switches to it -- which is why this is a
// layer surface with exclusive keyboard focus. A window is drawn as itself
// where KWin gives a picture -- the card under the selection, with the
// compiled screencast module installed (see WindowThumbnail) -- and as its
// application's icon over a tint of its own everywhere else, as the design
// draws it.
//
// This file keeps what the overview knows -- the desktops, the selection,
// what a key does to it -- and the three parts it draws are files of their
// own, handed what they show: OverviewHeader, OverviewWindows (the cards)
// and OverviewStrip (every desktop, along the bottom).

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.theme
import qs.domain.config
import qs.domain.desktops
import qs.domain.windows
import qs.domain.surfaces

PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    // ---- what there is to choose from --------------------------------------

    // KWin's desktops, in KWin's order. Taken live rather than once: creating
    // one from the strip below has to appear without reopening.
    readonly property var desks: Desktops.desktops ?? []

    // ---- what the user has asked it to be ---------------------------------

    // Held, or left up. Held is Alt+Tab's behaviour and the default; left up
    // is closer to what Windows does, and is what somebody who wants to look
    // rather than flick wants.
    readonly property bool hold: ConfigStore.value("switching.overviewHold", true) === true
    readonly property bool showTitles: ConfigStore.value("switching.overviewTitles", true) === true
    readonly property bool showMinimised: ConfigStore.value("switching.overviewMinimised", true) === true
    readonly property bool showStrip: ConfigStore.value("switching.overviewStrip", true) === true
    readonly property int maxCardWidth: ConfigStore.value("switching.overviewCardWidth", 560)

    // Which desktop the selection is on, and which window on it -- -1 for the
    // desktop itself, which is what releasing the key then switches to.
    property int deskIndex: 0
    property int winIndex: -1

    readonly property var desk: win.desks[win.deskIndex] ?? null

    // A desktop can appear or go while this is open -- the strip below makes
    // one -- so the selection is kept inside the list rather than pointing
    // past the end of it, which drew a header saying "No desktops" over a
    // strip that was showing them.
    onDesksChanged: {
        if (win.desks.length === 0)
            win.deskIndex = 0;
        else if (win.deskIndex >= win.desks.length)
            win.deskIndex = win.desks.length - 1;
    }

    // Every desktop's windows, most recent first, worked out for all of them
    // at once. The strip shows each desktop's, and asking one desktop at a
    // time filtered and sorted every window once per desktop -- all over
    // again whenever any window changed.
    readonly property var windowsByDesk: {
        const out = {};
        for (const d of win.desks)
            if (d?.id)
                out[d.id] = [];
        const ids = Object.keys(out);
        for (const w of WindowsService.windows ?? []) {
            if (!win.showMinimised && w?.minimized)
                continue;
            const on = w?.desktops ?? [];
            // An empty list is KWin's "on all desktops".
            for (const id of on.length === 0 ? ids : on)
                out[id]?.push(w);
        }
        for (const id of ids)
            out[id].sort((a, b) => (b.stacking ?? -1) - (a.stacking ?? -1));
        return out;
    }

    function windowsOn(deskId) {
        return deskId ? (win.windowsByDesk[deskId] ?? []) : [];
    }

    readonly property var deskWindows: win.windowsOn(win.desk?.id ?? "")

    // What the keys do, for the header. Held in a property rather than written
    // into the Repeater's `model`: an array of object literals there is read
    // as an attempt to set the model to a count, and fails with "int
    // expected" against the object's second key.
    readonly property var hints: win.hold ? win._holdHints : win._stayHints

    readonly property var _stayHints: [
        { kbd: "Tab", meaning: "window" },
        { kbd: "↑ ↓", meaning: "desktop" },
        { kbd: "Enter", meaning: "switch" },
        { kbd: "Del", meaning: "remove" },
        { kbd: "Esc", meaning: "close" }
    ]

    readonly property var _holdHints: [
        { kbd: "Meta+Tab", meaning: "window" },
        { kbd: "↑ ↓", meaning: "desktop" },
        { kbd: "1…9", meaning: "jump" },
        { kbd: "Del", meaning: "remove" },
        { kbd: "Esc", meaning: "cancel" }
    ]

    function countLabel(n) {
        return n === 0 ? "empty" : n === 1 ? "1 window" : `${n} windows`;
    }

    // ---- moving about ------------------------------------------------------

    function stepDesk(delta) {
        const n = win.desks.length;
        if (n === 0)
            return;
        win.deskIndex = ((win.deskIndex + delta) % n + n) % n;
        win.winIndex = -1;
    }

    // Tab runs through the windows of the desktop under the selection and
    // then on to the next desktop, so the key alone reaches everything that
    // is open rather than stopping at the end of one desktop's cards.
    function stepWindow(delta) {
        const n = win.deskWindows.length;
        if (n === 0) {
            win.stepDesk(delta >= 0 ? 1 : -1);
            win.selectEdge(delta);
            return;
        }
        if (win.winIndex < 0) {
            win.winIndex = delta > 0 ? 0 : n - 1;
            return;
        }
        const next = win.winIndex + delta;
        if (next >= 0 && next < n) {
            win.winIndex = next;
            return;
        }
        if (win.desks.length <= 1) {
            win.winIndex = ((next % n) + n) % n;
            return;
        }
        win.stepDesk(delta > 0 ? 1 : -1);
        win.selectEdge(delta);
    }

    // The first or last window of the desktop just stepped onto, so carrying
    // on from one desktop to the next lands where the eye is already going.
    function selectEdge(delta) {
        const n = win.deskWindows.length;
        win.winIndex = n === 0 ? -1 : (delta > 0 ? 0 : n - 1);
    }

    // Removing the selected desktop. KWin moves whatever was on it to the one
    // before; the last desktop cannot go, because a session with no desktops
    // has nowhere to put a window.
    function removeDesk(index) {
        if (win.desks.length <= 1)
            return;
        const desk = win.desks[index];
        if (!desk || !desk.id)
            return;
        Desktops.remove(desk.id);
        if (win.deskIndex >= win.desks.length - 1)
            win.deskIndex = Math.max(0, win.desks.length - 2);
        win.winIndex = -1;
    }

    function commit() {
        const desk = win.desk;
        const chosen = win.winIndex >= 0 ? win.deskWindows[win.winIndex] : null;
        Surfaces.closeAll();
        if (desk && desk.id !== Desktops.currentId)
            Desktops.switchTo(desk.id);
        // The window last, so it is activated on the desktop just switched to
        // rather than dragging the old one back.
        if (chosen && chosen.uuid)
            WindowsService.activate(chosen.uuid);
    }

    Component.onCompleted: {
        // The desktop in front is where it opens, and the selection starts on
        // a *window* there rather than on the desktop itself: Tab steps
        // windows, so opening with a desktop selected put the highlight on
        // the strip at the bottom while the key moved the cards at the top.
        //
        // Which window: the one behind the front one, as Alt+Tab does, so a
        // press and release switches to what you were in before. Backwards
        // starts at the other end.
        const at = win.desks.findIndex(d => d && d.id === Desktops.currentId);
        win.deskIndex = at >= 0 ? at : 0;

        const here = win.deskWindows;
        if (here.length === 0)
            win.winIndex = -1;
        else if (Surfaces.overviewDelta < 0)
            win.winIndex = here.length - 1;
        else
            win.winIndex = here.length > 1 ? 1 : 0;
        Log.debug("surfaces", `overview: up on ${win.screen?.name}, ${win.desks.length} desktop(s)`);

        // The key was let go before this surface existed. See the same lines
        // in WindowSwitcher.qml.
        // A turn later, for the reason WindowSwitcher gives.
        if (win.hold && Surfaces.heldCommitFresh)
            Qt.callLater(win.commit);
    }

    // And the release that lands just *after* it opened, which the read above
    // cannot see. Meta+Tab races exactly as Alt+Tab does -- the press and the
    // release are two detached processes -- so a quick one left the overview
    // on screen with the key already up and nothing able to close it.
    //
    // Only meaningful while the overview closes on the key at all: with
    // `switching.overviewHold` off it stays until something is chosen, and a
    // release means nothing. See WindowSwitcher.qml for why the keyboard has
    // to be asked rather than the timing trusted.
    readonly property Connections _lateCommit: Connections {
        target: Surfaces

        function onHeldCommitAsked(): void {
            if (!win.hold || !Surfaces.heldCommitFresh || modifiers.status !== Loader.Ready)
                return;
            if (modifiers.item && !modifiers.item.held())
                win.commit();
        }
    }

    readonly property Loader _modifiers: Loader {
        id: modifiers
        source: Qt.resolvedUrl("../../platform/input/HeldModifiers.qml")
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            // Tab steps windows, not desktops: the key is held the same way
            // Alt+Tab is, and a person pressing Tab means "the next thing I
            // might switch to". The desktops move on the arrows, where the
            // strip along the bottom is.
            case Qt.Key_Tab:
            case Qt.Key_Right:
                win.stepWindow(1); event.accepted = true; break;
            case Qt.Key_Backtab:
            case Qt.Key_Left:
                win.stepWindow(-1); event.accepted = true; break;
            case Qt.Key_Down:
                win.stepDesk(1); event.accepted = true; break;
            case Qt.Key_Up:
                win.stepDesk(-1); event.accepted = true; break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                win.commit(); event.accepted = true; break;
            case Qt.Key_Escape:
                Surfaces.closeAll(); event.accepted = true; break;
            case Qt.Key_Delete:
            case Qt.Key_Backspace:
                win.removeDesk(win.deskIndex); event.accepted = true; break;
            default:
                // 1..9 jumps, as the design's Super+1…5 does.
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    const at = event.key - Qt.Key_1;
                    if (at < win.desks.length) {
                        win.deskIndex = at;
                        win.winIndex = -1;
                    }
                    event.accepted = true;
                }
                break;
            }
        }

        // Another press of the key. It never arrives as a key event -- KWin
        // grabs the shortcut first -- so it comes back through the shell as
        // another call, and this is where that becomes a step.
        Connections {
            target: Surfaces

            function onOverviewTickChanged(): void {
                win.stepWindow(Surfaces.overviewDelta);
            }
        }

        // Letting go of the modifier is what chooses. The key arrives here
        // because this surface holds the keyboard exclusively.
        Keys.onReleased: event => {
            if (!win.hold)
                return;   // left up on purpose: only a choice closes it
            if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L
                || event.key === Qt.Key_Super_R || event.key === Qt.Key_Alt) {
                win.commit();
                event.accepted = true;
            }
        }

        // Everything outside the cards closes without choosing.
        MouseArea {
            anchors.fill: parent
            onClicked: Surfaces.closeAll()
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.38)
            opacity: sheet.shown
        }

        Item {
            id: sheet

            anchors.fill: parent
            anchors.leftMargin: 44
            anchors.rightMargin: 44
            anchors.topMargin: 34
            anchors.bottomMargin: 28

            property real shown: 0
            NumberAnimation on shown { from: 0; to: 1; duration: Theme.animationMs; easing.type: Easing.OutCubic; running: true }
            opacity: sheet.shown

            // ---- header --------------------------------------------------
            OverviewHeader {
                id: header

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right

                desks: win.desks
                hints: win.hints
                hold: win.hold
            }

            // ---- the selected desktop's windows ---------------------------
            OverviewWindows {
                anchors.top: header.bottom
                anchors.bottom: win.showStrip ? strip.top : parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 26
                anchors.bottomMargin: 26

                desk: win.desk
                deskIndex: win.deskIndex
                deskWindows: win.deskWindows
                winIndex: win.winIndex
                hold: win.hold
                showTitles: win.showTitles
                maxCardWidth: win.maxCardWidth
                countLabel: n => win.countLabel(n)

                onEntered: index => win.winIndex = index
                onChosen: index => {
                    win.winIndex = index;
                    win.commit();
                }
            }

            // ---- every desktop, along the bottom -------------------------
            OverviewStrip {
                id: strip

                visible: win.showStrip
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                desks: win.desks
                desk: win.desk
                deskIndex: win.deskIndex
                deskWindows: win.deskWindows
                winIndex: win.winIndex
                windowsOn: deskId => win.windowsOn(deskId)
                countLabel: n => win.countLabel(n)

                onEntered: index => {
                    win.deskIndex = index;
                    win.winIndex = -1;
                }
                onChosen: index => {
                    win.deskIndex = index;
                    win.winIndex = -1;
                    win.commit();
                }
                onRemoveAsked: index => win.removeDesk(index)
            }
        }
    }
}
