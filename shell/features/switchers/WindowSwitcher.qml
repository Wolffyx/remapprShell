pragma ComponentBehavior: Bound

// Alt+Tab, drawn by this shell rather than by KWin.
//
// KWin draws a switcher of its own and this shell can style it (see
// theme/windowswitcher), which is the default and costs nothing. This is the
// other choice: `switching.windows: shell`, the design's card row, drawn here
// where the shell decides everything about it.
//
// A picture of a window is KWin's to give, over the screencast protocol,
// which a client has to speak in C++ -- the compiled module in plugin/ (see
// WindowThumbnail). With it installed the selected card shows the window
// itself; every other card, and every card without it, carries the
// application's icon on a panel tinted per application, as the design draws
// them.
//
// Held-modifier behaviour is the reason this is a layer surface with exclusive
// keyboard focus: the key release that commits the choice only arrives at a
// window that holds the keyboard.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.theme
import qs.domain.windows
import qs.domain.windows.events
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

    // Most recently used first. The daemon reports KWin's stacking order --
    // higher is nearer the top -- which is what "the window I was in before
    // this one" means for a switcher. Taken once, when it opens: a list that
    // reordered itself as the selection moved would be unusable.
    property var entries: []

    function take() {
        const wins = (WindowsService.windows ?? []).slice();
        wins.sort((a, b) => (b.stacking ?? -1) - (a.stacking ?? -1));
        win.entries = wins;
        if (wins.length === 0) {
            win.index = 0;
        } else if (Surfaces.windowSwitcherDelta < 0) {
            // Opened by the backwards key: the last one, as Alt+Shift+Tab
            // means "the one at the other end".
            win.index = wins.length - 1;
        } else {
            // The second window, not the first: Alt+Tab means "the one before
            // this", and the first is the one in front.
            win.index = wins.length > 1 ? 1 : 0;
        }
    }

    property int index: 0

    function step(delta) {
        const n = win.entries.length;
        if (n === 0)
            return;
        win.index = ((win.index + delta) % n + n) % n;
    }

    function commit() {
        const chosen = win.entries[win.index];
        Surfaces.closeAll();
        if (chosen && chosen.uuid)
            WindowsService.activate(chosen.uuid);
    }

    Component.onCompleted: {
        win.take();
        Log.debug("surfaces", `window switcher: up on ${win.screen?.name}, ${win.entries.length} window(s)`);

        // The key was let go before this surface existed -- a quick Alt+Tab.
        // The choice was still made, so make it, rather than leaving the
        // switcher up with the key already released and nothing to close it.
        //
        // Read here and nowhere else, deliberately. kglobalaccel reports the
        // release of the *shortcut*, which is Tab coming up -- not Alt -- so a
        // switcher that acted on it while already up closed on the first Tab
        // and could never be stepped through with the key held. Once this
        // surface exists it has the keyboard, and Alt coming up reaches it as
        // the key release below, which is the one that means "choose".
        //
        // A turn later, not now: committing closes the switcher, which empties
        // the Variants model this surface is still being created from, and Qt
        // reports that as a binding loop on `model`.
        if (Surfaces.heldCommitFresh)
            Qt.callLater(win.commit);
    }

    // The release that lands just *after* this surface opened.
    //
    // The read above covers a commit that beat the surface onto the screen.
    // The other order was uncovered: for a fast enough Alt+Tab the key is
    // already up by the time the surface exists, so nothing more will reach
    // the key handler below -- and the switcher stayed on screen with no way
    // left to close it, which is what "if I go too fast it stays open" was.
    //
    // It could not simply act on the commit, because a commit arriving while
    // the switcher is up means either "Alt came up, choose" or "Tab came up,
    // Alt is still down, stay", and kglobalaccel reports the same thing for
    // both. Timing cannot separate them; the keyboard can. So the modifier is
    // asked, and the switcher closes only when it really has been let go.
    //
    // Without the compiled module there is no one to ask, and this does
    // nothing at all -- leaving exactly the behaviour that shipped before it.
    readonly property Connections _lateCommit: Connections {
        target: Surfaces

        function onHeldCommitAsked(): void {
            if (!Surfaces.heldCommitFresh || modifiers.status !== Loader.Ready)
                return;
            // Called on the item rather than through a typed cast: naming the
            // type here would mean importing the optional module into this
            // file, which is the one thing the Loader exists to avoid -- and
            // an unimported name casts to null, so the call would throw and
            // the fix would quietly do nothing.
            Log.debug("surfaces", `window switcher: a release arrived while up; the key is ${modifiers.item?.held() ? "still down" : "up"}`);
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
            case Qt.Key_Tab:
            case Qt.Key_Right:
            case Qt.Key_Down:
                win.step(1); event.accepted = true; break;
            case Qt.Key_Backtab:
            case Qt.Key_Left:
            case Qt.Key_Up:
                win.step(-1); event.accepted = true; break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                win.commit(); event.accepted = true; break;
            case Qt.Key_Escape:
                Surfaces.closeAll(); event.accepted = true; break;
            }
        }

        // Another press of the switcher's own key. It never arrives as a key
        // event -- KWin grabs the shortcut before any client sees it -- so it
        // comes back through the shell as another call to open the switcher,
        // and this is where that becomes a step.
        Connections {
            target: Surfaces

            function onWindowSwitcherTickChanged(): void {
                win.step(Surfaces.windowSwitcherDelta);
            }
        }

        // Letting go of the modifier is what chooses, as it does in every
        // switcher: the key arrives here because this surface holds the
        // keyboard exclusively.
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
                win.commit();
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Surfaces.closeAll()
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.38)
            opacity: card.shown
        }

        // ---- the card ---------------------------------------------------
        Rectangle {
            id: card

            property real shown: 0
            NumberAnimation on shown { from: 0; to: 1; duration: Theme.animationMs; easing.type: Easing.OutCubic; running: true }

            anchors.centerIn: parent
            width: Math.min(parent.width - 80, body.implicitWidth + 52)
            height: body.implicitHeight + 46
            radius: 30
            color: Theme.glass
            border.width: 1
            border.color: Theme.out
            opacity: card.shown
            scale: 0.97 + 0.03 * card.shown

            Column {
                id: body
                anchors.centerIn: parent
                width: parent.width - 52
                spacing: 18

                // Header: what this is, how many, and that the key is held.
                Item {
                    width: parent.width
                    height: 30

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        PanelText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Windows"
                            font.pixelSize: 17
                            font.weight: Font.Medium
                            color: Theme.fg
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 24
                            width: countText.implicitWidth + 22
                            radius: 12
                            color: Theme.accC

                            PanelText {
                                id: countText
                                anchors.centerIn: parent
                                text: `${win.entries.length} open · most recent first`
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.acc
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26
                        width: heldRow.implicitWidth + 24
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
                                text: "Alt held"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.fg
                            }
                        }
                    }
                }

                // The cards themselves.
                Row {
                    id: cards
                    spacing: 14

                    Repeater {
                        model: win.entries

                        Rectangle {
                            id: tile

                            required property var modelData
                            required property int index

                            readonly property bool selected: tile.index === win.index

                            width: 196
                            height: 210
                            radius: 18
                            color: tile.selected ? Theme.accC : Theme.s2
                            border.width: tile.selected ? 2 : 1
                            border.color: tile.selected ? Theme.acc : Theme.out
                            y: tile.selected ? -4 : 0
                            Behavior on y { NumberAnimation { duration: 120 } }

                            // A colour per application, so two windows of one
                            // program look alike and two programs do not.
                            readonly property color tint: Qt.hsla(WindowEvents.tintHue(tile.modelData?.appId),
                                                                  0.34, Theme.dark ? 0.38 : 0.62, 1)

                            Rectangle {
                                id: panel
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 10
                                height: 118
                                radius: 12
                                clip: true
                                color: tile.tint
                                opacity: tile.modelData?.minimized ? 0.55 : 1

                                WindowThumbnail {
                                    anchors.fill: parent
                                    windowId: tile.modelData?.uuid ?? ""
                                    sourceAspect: WindowEvents.aspectOf(tile.modelData)
                                    iconScale: 0.45
                                    // The selected card alone: see the same
                                    // note in Overview.qml.
                                    live: tile.selected && !tile.modelData?.minimized
                                    iconName: WindowsService.iconFor(tile.modelData)
                                    iconFile: WindowsService.iconFileFor(tile.modelData)
                                }

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 22
                                    color: Qt.rgba(Theme.s1.r, Theme.s1.g, Theme.s1.b, 0.82)

                                    PanelText {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        verticalAlignment: Text.AlignVCenter
                                        text: tile.modelData?.title ?? ""
                                        elide: Text.ElideRight
                                        font.pixelSize: 9
                                        color: Theme.mut
                                    }
                                }
                            }

                            Row {
                                anchors.top: panel.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 10
                                anchors.topMargin: 11
                                spacing: 10

                                Rectangle {
                                    width: 36; height: 36; radius: 12
                                    color: tile.selected ? Theme.acc : Theme.s1

                                    PanelIcon {
                                        anchors.centerIn: parent
                                        implicitSize: 20
                                        iconName: WindowsService.iconFor(tile.modelData)
                                        iconFile: WindowsService.iconFileFor(tile.modelData)
                                    }
                                }

                                Column {
                                    width: parent.width - 46
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    PanelText {
                                        width: parent.width
                                        text: WindowsService.appNameFor(tile.modelData)
                                        elide: Text.ElideRight
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: tile.selected ? Theme.accCFg : Theme.fg
                                    }
                                    PanelText {
                                        width: parent.width
                                        text: tile.modelData?.minimized ? "Minimised"
                                            : tile.modelData?.active ? "In front" : "Open"
                                        elide: Text.ElideRight
                                        font.pixelSize: 11
                                        color: tile.selected ? Theme.accCFg : Theme.mut
                                    }
                                }
                            }

                            TapHandler {
                                onTapped: { win.index = tile.index; win.commit(); }
                            }
                            HoverHandler {
                                onHoveredChanged: if (hovered) win.index = tile.index
                            }
                        }
                    }
                }

                // Footer: the chosen window, and what the keys do.
                Item {
                    width: parent.width
                    height: 44

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width
                        height: 1
                        color: Theme.out
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        width: parent.width * 0.5
                        spacing: 3

                        PanelText {
                            width: parent.width
                            text: win.entries[win.index]?.title ?? "No open windows"
                            elide: Text.ElideMiddle
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: Theme.fg
                        }
                        PanelText {
                            width: parent.width
                            text: win.index === 0 ? "currently in front" : `${win.index} back in the stack`
                            font.pixelSize: 12
                            color: Theme.mut
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: 8

                        Repeater {
                            model: [
                                { key: "Tab", what: "next" },
                                { key: "Shift+Tab", what: "back" },
                                { key: "Alt ↑", what: "focus" },
                                { key: "Esc", what: "cancel" }
                            ]

                            Row {
                                id: hint
                                required property var modelData
                                spacing: 6

                                KeyCap {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: hint.modelData.key
                                    pixelSize: 11
                                }
                                PanelText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: hint.modelData.what
                                    font.pixelSize: 12
                                    color: Theme.mut
                                    rightPadding: 6
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
