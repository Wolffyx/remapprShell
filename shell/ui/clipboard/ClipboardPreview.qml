// The selected entry, whole: all of a text where the list showed one line,
// a link's host above its address, a colour as a swatch, a picture as
// itself -- and what can be done with it.
//
// Pin and Remove are offered only where they work. Klipper's DBus interface
// has neither, so with Plasma's history they are not drawn at all.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.ui.controls
import qs.ui.primitives

Item {
    id: pane

    property var entry: null
    property real now: Date.now()

    signal copyRequested
    signal pinRequested
    signal removeRequested

    readonly property string kind: ClipboardHistory.clipboardKind(pane.entry)
    readonly property string body: String(pane.entry?.text ?? "")
    readonly property bool textual: pane.kind !== "image" && pane.kind !== "link" && pane.kind !== "colour"

    // ---- what it is, and when -----------------------------------------------

    Item {
        id: head
        width: parent.width
        height: 18
        visible: !!pane.entry

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            text: ClipboardHistory.clipboardKindLabel(pane.kind).toUpperCase()
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.8
            color: Theme.mut
        }

        PanelText {
            // How the short ages read in a sentence; the rest are "... ago".
            readonly property var said: ({ "": "", now: "Copied just now", yesterday: "Copied yesterday" })
            readonly property string age: ClipboardHistory.clipboardAge(pane.entry?.time ?? 0, pane.now)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 12
            color: Theme.mut
            text: said[age] ?? `Copied ${age} ago`
        }
    }

    // ---- the thing itself ---------------------------------------------------

    Rectangle {
        id: box
        anchors.top: head.bottom
        anchors.topMargin: 12
        anchors.bottom: actions.top
        anchors.bottomMargin: 12
        width: parent.width
        visible: !!pane.entry
        radius: Theme.radiusTiny + 3
        color: Theme.s2
        clip: true

        PanelText {
            anchors.fill: parent
            anchors.margins: 14
            visible: pane.textual
            verticalAlignment: Text.AlignTop
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideRight
            lineHeight: 1.4
            font.family: ClipboardHistory.clipboardKindMono(pane.kind) ? Theme.monoFamily : Theme.fontFamily
            font.pixelSize: ClipboardHistory.clipboardKindMono(pane.kind) ? 12 : 14
            textFormat: Text.PlainText
            text: pane.textual ? pane.body : ""
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            visible: pane.kind === "link"
            spacing: 8

            Glyph {
                name: "link"
                fallback: "link"
                size: 24
                color: Theme.acc
            }

            PanelText {
                width: parent.width
                elide: Text.ElideRight
                font.pixelSize: 15
                font.weight: Font.Medium
                text: pane.kind === "link" ? ClipboardHistory.clipboardHost(pane.body) : ""
            }

            PanelText {
                width: parent.width
                wrapMode: Text.WrapAnywhere
                lineHeight: 1.4
                maximumLineCount: 8
                elide: Text.ElideRight
                font.family: Theme.monoFamily
                font.pixelSize: 12
                color: Theme.mut
                textFormat: Text.PlainText
                text: pane.kind === "link" ? pane.body.trim() : ""
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            visible: pane.kind === "colour"
            spacing: 10

            Rectangle {
                width: parent.width
                height: 132
                radius: Theme.radiusSmall
                color: pane.kind === "colour" ? ClipboardHistory.clipboardSwatch(pane.body) : "transparent"
                border.width: 1
                border.color: Theme.out
            }

            PanelText {
                font.family: Theme.monoFamily
                font.pixelSize: 18
                font.weight: Font.Medium
                text: pane.kind === "colour" ? pane.body.trim() : ""
            }

            PanelText {
                font.family: Theme.monoFamily
                font.pixelSize: 12
                color: Theme.mut
                text: pane.kind === "colour" ? ClipboardHistory.clipboardRgb(pane.body) : ""
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            visible: pane.kind === "image"
            spacing: 10

            Rectangle {
                width: parent.width
                height: Math.max(80, parent.height - 54)
                radius: Theme.radiusSmall
                color: Theme.s1
                border.width: 1
                border.color: Theme.out
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: !!pane.entry?.path
                    source: pane.kind === "image" && pane.entry?.path ? `file://${pane.entry.path}` : ""
                    sourceSize: Qt.size(640, 480)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                }

                Glyph {
                    anchors.centerIn: parent
                    visible: !pane.entry?.path
                    name: "image"
                    fallback: "image-x-generic"
                    size: 32
                    color: Theme.mut
                }
            }

            PanelText {
                font.pixelSize: 14
                font.weight: Font.Medium
                text: "Image"
            }

            PanelText {
                width: parent.width
                elide: Text.ElideRight
                font.pixelSize: 12
                color: Theme.mut
                text: pane.kind === "image" ? ClipboardHistory.clipboardMeta(pane.entry) : ""
            }
        }
    }

    // ---- what to do with it -------------------------------------------------

    Item {
        id: actions
        anchors.bottom: parent.bottom
        width: parent.width
        height: 34
        visible: !!pane.entry

        Row {
            spacing: 8

            TextButton {
                text: "Copy"
                glyph: "content_copy"
                iconName: "edit-copy"
                primary: true
                enabled: ClipboardStatus.pickable(pane.entry)
                onActivated: pane.copyRequested()
            }

            TextButton {
                visible: ClipboardStatus.editable
                text: pane.entry?.pinned ? "Unpin" : "Pin"
                glyph: "push_pin"
                iconName: "pin"
                onActivated: pane.pinRequested()
            }
        }

        IconButton {
            anchors.right: parent.right
            visible: ClipboardStatus.editable
            glyph: "delete"
            iconName: "edit-delete"
            tooltip: "Remove from history"
            color: Theme.mut
            onActivated: pane.removeRequested()
        }
    }
}
