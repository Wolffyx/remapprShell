pragma ComponentBehavior: Bound

// Clipboard history.
//
// Under our renderer Plasma's Klipper is not running at all -- see
// ClipboardStatus for why -- so without this there is no history. With
// Klipper running, this is a view of Klipper's and changes nothing.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.ui.controls
import qs.ui.primitives

BarWidget {
    id: root

    readonly property int shown: root.widgetConfig?.shown ?? 15

    tooltip: ClipboardStatus.entries.length === 0 ? "Clipboard history is empty"
           : ClipboardStatus.entries.length === 1 ? "Clipboard: 1 entry"
           : `Clipboard: ${ClipboardStatus.entries.length} entries`

    implicitWidth: 24
    implicitHeight: 24

    function handleActivate(button) {
        root.popoutVisible = !root.popoutVisible;
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: (hover.hovered || root.popoutVisible) ? Theme.hoverBackground : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        PanelIcon {
            anchors.centerIn: parent
            implicitSize: 18
            iconName: "klipper-symbolic"
            fallbackName: "edit-paste"
        }

        HoverHandler { id: hover }
    }

    popout: Component {
        Item {
            implicitWidth: 340
            implicitHeight: body.implicitHeight

            Column {
                id: body
                width: parent.width
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 8

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - clear.width - 8
                        text: "Clipboard"
                        font.bold: true
                    }

                    IconButton {
                        id: clear
                        anchors.verticalCenter: parent.verticalCenter
                        visible: ClipboardStatus.entries.length > 0
                        iconName: "edit-clear-history"
                        onActivated: ClipboardStatus.clear()
                    }
                }

                PanelText {
                    visible: ClipboardStatus.source === "own"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Theme.foregroundInactive
                    font.pixelSize: 10
                    text: "Plasma's clipboard manager is not running, so this shell keeps the history: text only, in memory, gone when the shell stops. Nothing a password manager marks secret is kept."
                }

                Repeater {
                    model: ClipboardStatus.entries.slice(0, root.shown)

                    Rectangle {
                        id: row

                        required property var modelData

                        width: body.width
                        height: 26
                        radius: 5
                        color: rowHover.hovered && !row.modelData.image ? Theme.hoverBackground : "transparent"
                        opacity: row.modelData.image ? 0.5 : 1

                        PanelIcon {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 14
                            iconName: row.modelData.image ? "image-x-generic" : "edit-paste"
                        }

                        PanelText {
                            x: 28
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 34
                            elide: Text.ElideRight
                            font.pixelSize: 11
                            text: row.modelData.image ? "An image -- choose it from Plasma's clipboard (Meta+V)"
                                                      : StatusIcons.clipboardPreview(row.modelData.text, 80)
                        }

                        HoverHandler { id: rowHover }
                        TapHandler {
                            enabled: !row.modelData.image
                            onTapped: {
                                ClipboardStatus.pick(row.modelData);
                                root.popoutVisible = false;
                            }
                        }
                    }
                }

                PanelText {
                    visible: ClipboardStatus.entries.length === 0
                    width: parent.width
                    color: Theme.foregroundInactive
                    font.pixelSize: 11
                    text: "Nothing copied yet."
                }

                PanelText {
                    visible: ClipboardStatus.entries.length > root.shown
                    width: parent.width
                    color: Theme.foregroundInactive
                    font.pixelSize: 10
                    text: `and ${ClipboardStatus.entries.length - root.shown} older`
                }
            }
        }
    }
}
