pragma ComponentBehavior: Bound

// The clipboard history, where the pointer is.
//
// Meta+V on any desktop opens a menu under the pointer, and this is that menu:
// the last things copied, newest first, pictures among them, chosen with the
// pointer or with the keyboard. It used to be the panel widget's popout, which
// opens against the panel -- so a shortcut pressed while typing at the top of
// the screen answered at the bottom of it, beside an icon nobody was looking
// at.
//
// Where the pointer is comes from KWin, through the session daemon: see
// PointerRequests. The placement arithmetic is Place's, which is pure and
// tested, because the interesting case -- the pointer near an edge -- is the
// one nobody can check by hand.
//
// Choosing an entry copies it. It does not paste: a shell cannot type into
// somebody else's window on Wayland, and Klipper does not either.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.status
import qs.domain.status.icons
import qs.domain.surfaces
import qs.domain.surfaces.place
import qs.domain.theme
import qs.ui.controls
import qs.ui.primitives

PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    readonly property int maxShown: 12
    readonly property var entries: ClipboardStatus.entries.slice(0, win.maxShown)

    readonly property int cardWidth: 380

    // The card is as tall as its rows and no taller than this, and what does
    // not fit scrolls. Measured from the contents rather than from the card,
    // which would be a loop -- and the card must clip, or the rows past the
    // cap are drawn outside it, over whatever is on the screen.
    readonly property int cardHeight: Math.min(520, Math.round(body.implicitHeight) + 24)

    readonly property var spot: Place.atPointer(Surfaces.clipboardX, Surfaces.clipboardY,
                                                { x: win.screen?.x ?? 0, y: win.screen?.y ?? 0,
                                                  width: win.width, height: win.height },
                                                win.cardWidth, win.cardHeight, 8)

    // The whole screen, transparent, with the menu drawn inside it -- which is
    // how a menu behaves: a click anywhere else puts it away, and the click
    // does not reach what is underneath. A small surface could not do that
    // without a second one over the screen to catch the click.
    anchors { top: true; bottom: true; left: true; right: true }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: `${Branding.slug}-clipboard`
    color: "transparent"

    property int index: 0

    function choose(i) {
        const entry = win.entries[i];
        if (!entry || !ClipboardStatus.pickable(entry))
            return;
        ClipboardStatus.pick(entry);
        Surfaces.closeClipboard();
    }

    // Anywhere but the menu puts it away.
    TapHandler {
        onTapped: Surfaces.closeClipboard()
    }

    Rectangle {
        id: card

        x: win.spot.x
        y: win.spot.y
        width: win.cardWidth
        height: win.cardHeight
        radius: Theme.radius
        color: Theme.glass
        border.width: 1
        border.color: Theme.out
        clip: true

        focus: true
        Keys.onEscapePressed: Surfaces.closeClipboard()
        Keys.onUpPressed: win.index = Math.max(0, win.index - 1)
        Keys.onDownPressed: win.index = Math.min(win.entries.length - 1, win.index + 1)
        Keys.onReturnPressed: win.choose(win.index)
        Keys.onEnterPressed: win.choose(win.index)

        Flickable {
            id: scroll

            anchors.fill: parent
            anchors.margins: 12
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body

                // The Flickable by name: a child of one is parented to its
                // content item, and `parent.width` there is not the width the
                // rows have to fit in.
                width: scroll.width
                spacing: 6

                Item {
                    width: parent.width
                    height: 22

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clipboard"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.mut
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: ClipboardStatus.entries.length > 0
                        size: 24
                        glyph: "clear_all"
                        iconName: "edit-clear-history"
                        color: Theme.mut
                        onActivated: {
                            ClipboardStatus.clear();
                            Surfaces.closeClipboard();
                        }
                    }
                }

                Hint {
                    visible: ClipboardStatus.entries.length === 0
                    text: "Nothing copied yet."
                    lineHeight: 1
                }

                Repeater {
                    model: win.entries

                    Rectangle {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool choosable: ClipboardStatus.pickable(row.modelData)
                        readonly property bool current: win.index === row.index

                        width: body.width
                        height: row.modelData.image ? 64 : 30
                        radius: Theme.radiusOf(10)
                        color: row.current || hover.hovered ? Theme.alpha(Theme.fg, 0.08) : "transparent"
                        opacity: row.choosable ? 1 : 0.55

                        // A picture is shown as one: a thumbnail of the file the
                        // watcher wrote, which is the only way to tell two
                        // screenshots apart.
                        Rectangle {
                            id: thumb
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.modelData.image
                            width: visible ? 72 : 0
                            height: 52
                            radius: Theme.radiusOf(8)
                            color: Theme.s2
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: row.modelData.path ? `file://${row.modelData.path}` : ""
                                sourceSize: Qt.size(216, 156)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }
                        }

                        PanelIcon {
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !row.modelData.image
                            implicitSize: 14
                            iconName: "edit-paste"
                        }

                        PanelText {
                            x: row.modelData.image ? 88 : 30
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 8
                            elide: Text.ElideRight
                            wrapMode: row.modelData.image ? Text.NoWrap : Text.NoWrap
                            font.pixelSize: 12
                            text: row.choosable
                                ? StatusIcons.clipboardLabel(row.modelData, 70)
                                : `${StatusIcons.clipboardLabel(row.modelData, 60)} — Plasma's, choose it there`
                        }

                        HoverHandler {
                            id: hover
                            cursorShape: row.choosable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onHoveredChanged: if (hovered) win.index = row.index
                        }

                        TapHandler {
                            enabled: row.choosable
                            onTapped: win.choose(row.index)
                        }
                    }
                }

                PanelText {
                    visible: ClipboardStatus.entries.length > win.maxShown
                    width: parent.width
                    text: `and ${ClipboardStatus.entries.length - win.maxShown} older`
                    font.pixelSize: 10
                    color: Theme.mut
                }
            }
        }
    }

    Connections {
        target: Surfaces
        function onClipboardChanged() {
            if (Surfaces.clipboard)
                win.index = 0;
        }
    }
}
