pragma ComponentBehavior: Bound

// Clipboard history.
//
// Under our renderer Plasma's Klipper is not running at all -- see
// ClipboardStatus for why -- so without this there is no history. With
// Klipper running, this is a view of Klipper's and changes nothing.
//
// The popout is the same card Meta+V opens at the pointer (ClipboardCard),
// so it searches, filters, pins and answers to the same keys: it takes the
// keyboard while it is open, which is what makes typing into it work.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.surfaces
import qs.ui.clipboard
import qs.ui.primitives

BarWidget {
    id: root

    tooltip: ClipboardStatus.entries.length === 0 ? "Clipboard history is empty"
           : ClipboardStatus.entries.length === 1 ? "Clipboard: 1 entry"
           : `Clipboard: ${ClipboardStatus.entries.length} entries`

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    popoutGrabsFocus: true
    popoutPadding: 16

    function handleActivate(button) {
        root.popoutVisible = !root.popoutVisible;
    }

    BarButton {
        id: button
        thickness: root.barThickness
        hovered: root.hovered
        active: root.popoutVisible
        size: root.tileSize
        glyph: "content_paste"
        fallback: "klipper-symbolic"
        glyphSize: root.panelIconSize
    }

    // "Copied" beside the button, clear of the panel: the panel spans its
    // edge, so where the button sits in it is where it sits on the screen.
    function sayCopied(entry) {
        const centre = button.mapToItem(null, button.width / 2, button.height / 2);
        Surfaces.showCopied({
            label: ClipboardHistory.clipboardLabel(entry, 40),
            screen: root.screenName,
            edge: root.bar?.position ?? "bottom",
            along: root.barVertical ? centre.y : centre.x,
            offset: root.bar?.extent ?? root.barThickness
        });
    }

    popout: Component {
        ClipboardCard {
            onCloseRequested: root.closePopout()
            onChosen: entry => root.sayCopied(entry)
        }
    }
}
