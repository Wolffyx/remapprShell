pragma ComponentBehavior: Bound

// The clipboard history, where the pointer is.
//
// Meta+V on any desktop opens a menu under the pointer, and this is that menu:
// the last things copied, newest first, pictures among them, chosen with the
// pointer or with the keyboard. It used to be the panel widget's popout, which
// opens against the panel -- so a shortcut pressed while typing at the top of
// the screen answered at the bottom of it, beside an icon nobody was looking
// at. The two are one card now (ClipboardCard): this places it at the
// pointer, the widget's popout under its button.
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
import qs.domain.surfaces
import qs.domain.surfaces.place
import qs.domain.status.icons
import qs.domain.theme
import qs.ui.clipboard

PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    readonly property int padding: 16
    readonly property int cardWidth: Math.round(clip.implicitWidth) + 2 * win.padding
    readonly property int cardHeight: Math.round(clip.implicitHeight) + 2 * win.padding

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

    // Anywhere but the menu puts it away.
    TapHandler {
        onTapped: Surfaces.closeClipboard()
    }

    Rectangle {
        id: frame

        x: win.spot.x
        y: win.spot.y
        width: win.cardWidth
        height: win.cardHeight
        radius: Theme.radius
        color: Theme.glass
        border.width: 1
        border.color: Theme.out

        // Presses on the card are its own, not the screen's behind it.
        MouseArea { anchors.fill: parent }

        ClipboardCard {
            id: clip
            anchors.fill: parent
            anchors.margins: win.padding
            onCloseRequested: Surfaces.closeClipboard()
            onChosen: entry => Surfaces.showCopied({
                label: ClipboardHistory.clipboardLabel(entry, 40),
                screen: win.screen?.name ?? "",
                x: Surfaces.clipboardX,
                y: Surfaces.clipboardY
            })
        }
    }

    // The window is kept between openings; the card is told each time.
    Connections {
        target: Surfaces
        function onClipboardChanged() {
            if (Surfaces.clipboard)
                clip.focusField();
        }
    }
}
