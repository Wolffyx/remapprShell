// One entry in the clipboard's list: what it is at a glance -- a picture of
// a picture, a swatch of a colour, a glyph for the rest -- its first line,
// the line under it, whether it is pinned, how long ago, and the digit
// Alt picks it with.
//
// The selected row is drawn in the accent's container colour, as the current
// option in any list is. Hover does not select it: the card decides, from
// whether the pointer really moved (see ClipboardCard.pointerMoved).

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: row

    required property var entry
    required property bool current
    // "1" to "9" for a row Alt can pick, empty for the rest.
    property string digit: ""
    property real now: Date.now()

    signal pointed(point scenePosition)
    signal chosen

    readonly property string kind: ClipboardHistory.clipboardKind(row.entry)
    readonly property bool choosable: ClipboardStatus.pickable(row.entry)
    readonly property color ink: row.current ? Theme.accCFg : Theme.fg
    readonly property color subInk: row.current ? Theme.accCFg : Theme.mut

    implicitHeight: 48
    radius: Theme.radiusSmall
    color: row.current ? Theme.accC : "transparent"
    opacity: row.choosable ? 1 : 0.55
    Behavior on color { ColorAnimation { duration: 100 } }

    Accessible.role: Accessible.ListItem
    Accessible.name: `${ClipboardHistory.clipboardKindLabel(row.kind)}: ${title.text}`
    Accessible.selected: row.current

    // ---- the lead: a picture, a swatch or a glyph ---------------------------

    Item {
        id: lead
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 32

        Rectangle {
            anchors.fill: parent
            visible: row.kind === "image"
            radius: Theme.radiusTiny
            color: Theme.s2
            border.width: 1
            border.color: Theme.out
            clip: true

            // The file the watcher wrote: the only way to tell two
            // screenshots apart. Klipper's pictures have no file of ours.
            Image {
                anchors.fill: parent
                anchors.margins: 1
                visible: !!row.entry?.path
                source: row.entry?.path ? `file://${row.entry.path}` : ""
                sourceSize: Qt.size(132, 96)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            Glyph {
                anchors.centerIn: parent
                visible: !row.entry?.path
                name: "image"
                fallback: "image-x-generic"
                size: 18
                color: Theme.mut
            }
        }

        Rectangle {
            anchors.centerIn: parent
            visible: row.kind === "colour"
            width: 24
            height: 24
            radius: 12
            color: row.kind === "colour" ? ClipboardHistory.clipboardSwatch(row.entry?.text) : "transparent"
            border.width: 1
            border.color: Theme.out
        }

        Rectangle {
            anchors.fill: parent
            visible: row.kind !== "image" && row.kind !== "colour"
            radius: Theme.radiusTiny
            color: Theme.hover

            Glyph {
                anchors.centerIn: parent
                name: ClipboardHistory.clipboardKindGlyph(row.kind)
                fallback: "edit-paste"
                size: 18
                color: row.ink
            }
        }
    }

    // ---- the words ----------------------------------------------------------

    Column {
        anchors.left: lead.right
        anchors.leftMargin: 12
        anchors.right: trail.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        PanelText {
            id: title
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: 13
            color: row.ink
            text: row.kind === "image" ? "Image" : ClipboardHistory.clipboardPreview(row.entry?.text, 120)
        }

        PanelText {
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: 12
            color: row.subInk
            opacity: row.current ? 0.8 : 1
            text: row.choosable ? ClipboardHistory.clipboardMeta(row.entry)
                                : "Plasma's · choose it in Plasma's clipboard"
        }
    }

    // ---- the end: pin, age, digit -------------------------------------------

    Row {
        id: trail
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!row.entry?.pinned
            name: "push_pin"
            fallback: "pin"
            filled: true
            size: 16
            color: row.current ? Theme.accCFg : Theme.acc
        }

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 12
            color: row.subInk
            text: ClipboardHistory.clipboardAge(row.entry?.time ?? 0, row.now)
        }

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            horizontalAlignment: Text.AlignRight
            font.family: Theme.monoFamily
            font.pixelSize: 11
            color: row.subInk
            text: row.digit
        }
    }

    HoverHandler {
        id: hover
        cursorShape: row.choosable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPointChanged: if (hover.hovered) row.pointed(hover.point.scenePosition)
    }

    TapHandler {
        enabled: row.choosable
        onTapped: row.chosen()
    }
}
