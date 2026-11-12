pragma ComponentBehavior: Bound

// "Copied", for a moment, after an entry is chosen from the clipboard history.
//
// Choosing copies and closes; it cannot paste, because a shell cannot type
// into another window on Wayland. So this says where the entry went: shown
// for a second and a half where the choice was made -- at the pointer for
// Meta+V, beside the button for the panel's popout -- and then gone. It takes
// no input and reserves nothing, like the OSD. `clipboard.confirm` turns it
// off for people who find it noise; Surfaces.copied says what and where.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.surfaces
import qs.domain.surfaces.place
import qs.domain.theme
import qs.ui.primitives

PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    readonly property var note: Surfaces.copied
    readonly property var area: ({ x: win.screen?.x ?? 0, y: win.screen?.y ?? 0, width: win.width, height: win.height })

    // Where the card goes: at the pointer, or beside the panel button.
    readonly property var spot: (win.note?.edge ?? "").length > 0
        ? Place.atEdge(win.note.edge, win.note.along, win.note.offset, win.area, body.width, body.height, 8)
        : Place.atPointer(win.note?.x ?? 0, win.note?.y ?? 0, win.area, body.width, body.height, 12)

    // The whole screen, transparent and deaf, with the card drawn inside it:
    // a layer surface cannot be sized to its content in one direction only.
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: `${Branding.slug}-copied`
    color: "transparent"

    // Each new one shows for its own full time.
    Timer {
        id: life
        interval: 1500
        running: true
        onTriggered: Surfaces.hideCopied()
    }

    onNoteChanged: {
        if (win.note)
            life.restart();
    }

    RectangularShadow {
        visible: Theme.shadows
        anchors.fill: body
        radius: body.radius
        blur: 28
        offset.y: 8
        color: Theme.shadow
    }

    Rectangle {
        id: body

        x: win.spot.x
        y: win.spot.y
        // Sized from the title's own width, not from the column holding it:
        // the column's width comes from this, and asking it back is a loop
        // that elides the title to nothing.
        width: Math.min(360, Math.max(220, title.implicitWidth + 30 + 32))
        height: lines.implicitHeight + 28
        radius: Theme.radius
        color: Theme.glass
        border.width: 1
        border.color: Theme.out

        Column {
            id: lines
            x: 16
            y: 14
            width: body.width - 32
            spacing: 6

            Row {
                spacing: 10

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check_circle"
                    fallback: "dialog-ok"
                    filled: true
                    size: 20
                    color: Theme.positive
                }

                PanelText {
                    id: title
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, body.width - 32 - 30)
                    text: `Copied · ${win.note?.label ?? ""}`
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }

            PanelText {
                text: "Paste it with Ctrl+V."
                font.pixelSize: 12
                color: Theme.mut
            }
        }
    }
}
