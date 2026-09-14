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
// layer surface with exclusive keyboard focus. What it cannot do is show a
// picture of each window; KWin gives those to its own layouts only. So a
// window is its application's icon over a tint of its own, as the design
// draws it.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.theme
import qs.domain.config
import qs.domain.desktops
import qs.domain.windows
import qs.domain.surfaces
import qs.ui.primitives

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

    function windowsOn(deskId) {
        if (!deskId)
            return [];
        const all = WindowsService.windows ?? [];
        return all.filter(w => {
            if (!win.showMinimised && w?.minimized)
                return false;
            const on = w?.desktops ?? [];
            // An empty list is KWin's "on all desktops".
            return on.length === 0 || on.indexOf(deskId) >= 0;
        }).sort((a, b) => (b.stacking ?? -1) - (a.stacking ?? -1));
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
        // in WindowSwitcher.qml: read here and nowhere else.
        if (win.hold && Surfaces.heldCommitFresh)
            win.commit();
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
            Rectangle {
                id: header

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 56
                radius: Theme.radiusOf(20)
                color: Theme.glass
                border.width: 1
                border.color: Theme.out

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "grid_view"
                        fallback: "preferences-desktop-virtual"
                        size: 24
                        color: Theme.acc
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Desktops"
                        font.pixelSize: 19
                        font.weight: Font.Medium
                        color: Theme.fg
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26
                        width: deskCount.implicitWidth + 24
                        radius: 13
                        color: Theme.accC

                        PanelText {
                            id: deskCount
                            anchors.centerIn: parent
                            text: `${win.desks.length} desktop${win.desks.length === 1 ? "" : "s"} · in front ${
                                (win.desks.findIndex(d => d && d.id === Desktops.currentId) + 1) || 1}`
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Theme.acc
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: win.hints

                        Row {
                            required property var modelData
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 22
                                width: hintKey.implicitWidth + 18
                                radius: 8
                                color: Theme.s2
                                border.width: 1
                                border.color: Theme.out

                                PanelText {
                                    id: hintKey
                                    anchors.centerIn: parent
                                    text: modelData.kbd
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: Theme.fg
                                }
                            }

                            PanelText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.meaning
                                font.pixelSize: 12
                                color: Theme.mut
                            }
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26
                        width: heldRow.implicitWidth + 26
                        radius: 13
                        color: Theme.s2
                        border.width: 1
                        border.color: Theme.out

                        Row {
                            id: heldRow
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7; height: 7; radius: 4
                                color: Theme.acc
                            }
                            PanelText {
                                text: win.hold ? "Meta held" : "Open until you choose"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.fg
                            }
                        }
                    }
                }
            }

            // ---- the selected desktop's windows ---------------------------
            Column {
                id: middle

                anchors.top: header.bottom
                anchors.bottom: win.showStrip ? strip.top : parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 26
                anchors.bottomMargin: 26
                spacing: 20

                // What is selected, said in words: with nothing but cards on
                // screen there is nowhere else to read what releasing the key
                // would do.
                Row {
                    id: pills

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Repeater {
                        model: [
                            win.desk ? `Desktop ${win.deskIndex + 1}${win.desk.name ? ` · ${win.desk.name}` : ""}`
                                     : "No desktops",
                            win.countLabel(win.deskWindows.length),
                            win.winIndex >= 0
                                ? (win.hold ? "Release Meta to switch here and raise this window"
                                            : "Enter, or click, to switch here and raise this window")
                                : win.deskWindows.length > 0
                                    ? (win.hold ? "Release Meta to switch here" : "Enter, or click, to switch here")
                                    : (win.hold ? "Release Meta for a clean desktop" : "Enter for a clean desktop")
                        ]

                        Rectangle {
                            required property string modelData

                            height: 34
                            width: pillText.implicitWidth + 30
                            radius: 17
                            color: Theme.glass
                            border.width: 1
                            border.color: Theme.out

                            PanelText {
                                id: pillText
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 14
                                color: Theme.fg
                            }
                        }
                    }
                }

                // The cards. Three to a row at most, as wide as the room
                // allows, and never so wide that two windows look like a
                // gallery of one.
                Flickable {
                    id: cardsArea

                    width: parent.width
                    height: middle.height - pills.height - middle.spacing
                    contentHeight: cards.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                Flow {
                    id: cards

                    width: parent.width
                    spacing: 22

                    // Centred while they fit, and scrolled when they do not:
                    // a desktop with eight windows on it is two rows of cards
                    // taller than the room between the header and the strip.
                    y: Math.max(0, (cardsArea.height - cards.implicitHeight) / 2)

                    // Centred across, too. Two cards of a capped width in a
                    // three-card row sat against the left edge under a header
                    // and pills that are both centred.
                    readonly property int inRow: Math.max(1, Math.min(win.deskWindows.length, cards.columns))
                    x: Math.max(0, (cardsArea.width
                                    - (cards.inRow * cards.cardWidth + cards.spacing * (cards.inRow - 1))) / 2)

                    readonly property int columns: Math.max(1, Math.min(win.deskWindows.length,
                                                                        Math.floor(cards.width / 430)))
                    readonly property real cardWidth: Math.min(win.maxCardWidth,
                        (cards.width - cards.spacing * (cards.columns - 1)) / cards.columns)

                    Repeater {
                        model: win.deskWindows

                        Rectangle {
                            id: card

                            required property var modelData
                            required property int index

                            readonly property bool selected: card.index === win.winIndex

                            width: cards.cardWidth
                            height: 372
                            radius: Theme.radiusOf(22)
                            color: card.selected ? Theme.accC : Theme.s1
                            border.width: card.selected ? 2 : 1
                            border.color: card.selected ? Theme.acc : Theme.out
                            // The lift is a transform, not a `y`. A Flow
                            // positions both x and y of its children, so a
                            // card that sets its own y fights the positioner
                            // and the row lands on top of itself -- which is
                            // what "the apps list are moving one over each
                            // other" was. The switcher can set y because a
                            // Row positions x alone.
                            property real lift: card.selected ? 3 : 0
                            Behavior on lift { NumberAnimation { duration: 120 } }
                            transform: Translate { y: -card.lift }

                            // A colour per application, as the switcher's
                            // cards use, so the same program looks the same in
                            // both.
                            readonly property color tint: {
                                const s = String(card.modelData?.appId ?? "");
                                let h = 0;
                                for (let i = 0; i < s.length; i++)
                                    h = (h * 31 + s.charCodeAt(i)) % 360;
                                return Qt.hsla(h / 360, 0.34, Theme.dark ? 0.38 : 0.62, 1);
                            }

                            Rectangle {
                                id: preview

                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 12
                                height: 296
                                radius: 14
                                clip: true
                                color: card.tint
                                opacity: card.modelData?.minimized ? 0.55 : 1

                                // The window itself where KWin gives a
                                // picture, and the application's icon over
                                // the card's own tint where it does not.
                                WindowThumbnail {
                                    anchors.fill: parent
                                    anchors.topMargin: win.showTitles ? 34 : 0
                                    windowId: card.modelData?.uuid ?? ""
                                    iconName: WindowsService.iconFor(card.modelData)
                                    iconFile: WindowsService.iconFileFor(card.modelData)
                                    iconScale: 0.5
                                    sourceAspect: WindowEvents.aspectOf(card.modelData)
                                    // Only the card under the selection.
                                    //
                                    // Eleven windows meant eleven streams,
                                    // and the list is rebuilt whenever a
                                    // window opens or closes -- so streams
                                    // were created and destroyed in bursts and
                                    // PipeWire answered "target not found" for
                                    // all of them. One stream at a time is
                                    // also all a person is looking at.
                                    live: card.selected && !card.modelData?.minimized
                                }

                                Rectangle {
                                    visible: win.showTitles
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 34
                                    color: Qt.rgba(Theme.s1.r, Theme.s1.g, Theme.s1.b, 0.82)

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 8

                                        PanelIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            implicitSize: 16
                                            iconName: WindowsService.iconFor(card.modelData)
                                            iconFile: WindowsService.iconFileFor(card.modelData)
                                        }

                                        PanelText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 30
                                            text: card.modelData?.title ?? ""
                                            elide: Text.ElideRight
                                            font.pixelSize: 12
                                            color: Theme.mut
                                        }
                                    }
                                }
                            }

                            Row {
                                anchors.top: preview.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 12
                                anchors.topMargin: 14
                                spacing: 12

                                Rectangle {
                                    width: 42; height: 42; radius: 13
                                    color: card.selected ? Theme.acc : Theme.s2

                                    PanelIcon {
                                        anchors.centerIn: parent
                                        implicitSize: 23
                                        iconName: WindowsService.iconFor(card.modelData)
                                        iconFile: WindowsService.iconFileFor(card.modelData)
                                    }
                                }

                                Column {
                                    width: parent.width - 54
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    PanelText {
                                        width: parent.width
                                        text: WindowsService.appNameFor(card.modelData)
                                        elide: Text.ElideRight
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                        color: card.selected ? Theme.accCFg : Theme.fg
                                    }

                                    PanelText {
                                        width: parent.width
                                        text: card.modelData?.minimized ? "Minimised"
                                            : card.index === 0 ? "Top of the stack"
                                            : `${card.index} behind`
                                        elide: Text.ElideRight
                                        font.pixelSize: 12
                                        color: card.selected ? Theme.accCFg : Theme.mut
                                    }
                                }
                            }

                            TapHandler {
                                onTapped: { win.winIndex = card.index; win.commit(); }
                            }
                            HoverHandler {
                                onHoveredChanged: if (hovered) win.winIndex = card.index
                            }
                        }
                    }
                }

                }

                // Nothing open here. Worth saying plainly: an empty desktop is
                // a thing people switch to on purpose.
                Column {
                    visible: win.deskWindows.length === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "window"
                        fallback: "window"
                        size: 56
                        color: Theme.fg
                        opacity: 0.8
                    }

                    PanelText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Nothing open on this desktop"
                        font.pixelSize: 17
                        color: Theme.fg
                    }
                }
            }

            // ---- every desktop, along the bottom -------------------------
            Rectangle {
                id: strip

                visible: win.showStrip
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 196
                radius: Theme.radiusOf(24)
                color: Theme.glass
                border.width: 1
                border.color: Theme.out

                Row {
                    id: stripTitle

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 18
                    spacing: 12

                    PanelText {
                        text: "ALL DESKTOPS"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.letterSpacing: 0.8
                        color: Theme.mut
                    }

                    PanelText {
                        text: win.winIndex >= 0 && win.deskWindows[win.winIndex]
                            ? (win.deskWindows[win.winIndex].title ?? "")
                            : (win.desk ? `Desktop ${win.deskIndex + 1}${win.desk.name ? ` · ${win.desk.name}` : ""}` : "")
                        elide: Text.ElideRight
                        width: strip.width - 220
                        font.pixelSize: 13
                        color: Theme.fg
                    }
                }

                Row {
                    id: deskRow

                    anchors.top: stripTitle.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 18
                    anchors.topMargin: 12
                    spacing: 14

                    readonly property real cardWidth: {
                        const n = Math.max(1, win.desks.length);
                        const room = deskRow.width - newDesk.width - deskRow.spacing * n;
                        return Math.max(96, Math.min(240, room / n));
                    }

                    Repeater {
                        model: win.desks

                        Rectangle {
                            id: deskCard

                            required property var modelData
                            required property int index

                            readonly property bool selected: deskCard.index === win.deskIndex
                            readonly property bool current: deskCard.modelData?.id === Desktops.currentId
                            readonly property var deskWins: win.windowsOn(deskCard.modelData?.id ?? "")

                            width: deskRow.cardWidth
                            height: 148
                            radius: Theme.radiusOf(18)
                            color: deskCard.selected ? Theme.accC : Theme.s2
                            border.width: deskCard.selected ? 2 : 1
                            border.color: deskCard.selected ? Theme.acc : Theme.out

                            // A glance at what is on it: the applications, in
                            // stacking order, as many as fit.
                            Rectangle {
                                id: deskPreview

                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 10
                                height: 84
                                radius: 12
                                clip: true
                                color: Theme.s1

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 7

                                    Repeater {
                                        model: deskCard.deskWins.slice(0, 3)

                                        Rectangle {
                                            required property var modelData

                                            // Sized against the preview, not
                                            // `parent`: a Repeater delegate's
                                            // parent is null until it is
                                            // reparented, which is a TypeError
                                            // per tile and a tile of no height.
                                            width: (deskPreview.width - 16 - 2 * 7) / 3
                                            height: deskPreview.height - 16
                                            radius: 8
                                            color: Theme.glass
                                            border.width: 1
                                            border.color: Theme.out

                                            PanelIcon {
                                                anchors.centerIn: parent
                                                implicitSize: 19
                                                iconName: WindowsService.iconFor(modelData)
                                                iconFile: WindowsService.iconFileFor(modelData)
                                            }
                                        }
                                    }
                                }

                                PanelText {
                                    anchors.centerIn: parent
                                    visible: deskCard.deskWins.length === 0
                                    text: "Empty"
                                    font.pixelSize: 12
                                    color: Theme.mut
                                }
                            }

                            Row {
                                anchors.top: deskPreview.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 10
                                anchors.topMargin: 10
                                spacing: 9

                                Rectangle {
                                    width: 26; height: 26; radius: 9
                                    color: deskCard.current ? Theme.acc : Theme.s1

                                    PanelText {
                                        anchors.centerIn: parent
                                        text: String(deskCard.index + 1)
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: deskCard.current ? Theme.accFg : Theme.mut
                                    }
                                }

                                Column {
                                    width: parent.width - 44
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    PanelText {
                                        width: parent.width
                                        text: deskCard.modelData?.name ?? `Desktop ${deskCard.index + 1}`
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: deskCard.selected ? Theme.accCFg : Theme.fg
                                    }

                                    PanelText {
                                        width: parent.width
                                        text: win.countLabel(deskCard.deskWins.length)
                                        elide: Text.ElideRight
                                        font.pixelSize: 12
                                        color: deskCard.selected ? Theme.accCFg : Theme.mut
                                    }
                                }
                            }

                            // Taking one away, where the pointer already is.
                            // Kept out of the way until the card is hovered,
                            // and absent on the last desktop, which KWin will
                            // not remove.
                            Rectangle {
                                id: removeButton

                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: 24; height: 24
                                radius: 12
                                color: removeHover.hovered ? Theme.error : Theme.s1
                                opacity: (deskHover.hovered || removeHover.hovered) && win.desks.length > 1 ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 90 } }

                                Glyph {
                                    anchors.centerIn: parent
                                    name: "close"
                                    fallback: "window-close"
                                    size: 15
                                    color: removeHover.hovered ? Theme.errorFg : Theme.mut
                                }

                                HoverHandler { id: removeHover }
                                TapHandler {
                                    enabled: removeButton.opacity > 0
                                    onTapped: win.removeDesk(deskCard.index)
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    win.deskIndex = deskCard.index;
                                    win.winIndex = -1;
                                    win.commit();
                                }
                            }
                            HoverHandler {
                                id: deskHover
                                onHoveredChanged: if (hovered) {
                                    win.deskIndex = deskCard.index;
                                    win.winIndex = -1;
                                }
                            }
                        }
                    }

                    // One more desktop. KWin numbers and names them; this asks
                    // for one at the end and lets KWin do both.
                    Rectangle {
                        id: newDesk

                        width: 150
                        height: 148
                        radius: Theme.radiusOf(18)
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.out

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Glyph {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "add"
                                fallback: "list-add"
                                size: 26
                                color: Theme.mut
                            }

                            PanelText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "New desktop"
                                font.pixelSize: 12
                                color: Theme.mut
                            }
                        }

                        TapHandler {
                            onTapped: Desktops.create()
                        }
                    }
                }
            }
        }
    }
}
