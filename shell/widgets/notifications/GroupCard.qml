pragma ComponentBehavior: Bound

// One application's notifications, as the grouped centre shows them: the
// latest on a card, the rest stacked behind it until it is opened out.

import QtQuick
import Quickshell
import qs.domain.notifications.centre
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Item {
    id: card

    // The bell: whether Ask is offered and what it does, and the popout that
    // opening a notification puts away.
    required property var widget

    // { app, icon, entries }, from Centre.groups.
    required property var group
    required property real now
    property bool expanded: false

    readonly property var entries: card.group.entries
    readonly property int count: card.entries.length
    readonly property bool stacked: card.count > 1 && !card.expanded

    width: parent ? parent.width : 0
    height: face.height + (card.stacked ? 8 : 0)

    Rectangle {
        visible: card.stacked
        x: 12
        y: face.height - 30
        width: parent.width - 24
        height: 38
        radius: Theme.radiusOf(18)
        color: Theme.s2
    }

    Rectangle {
        id: face
        width: parent.width
        height: body.implicitHeight + 28
        radius: Theme.radiusOf(20)
        color: Theme.s1
        border.width: 1
        border.color: Theme.out

        Column {
            id: body
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 0

            Item {
                width: parent.width
                height: 20

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    NoteIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: card.group.icon
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.group.app
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.count > 1
                        width: countText.implicitWidth + 14
                        height: 18
                        radius: Theme.radiusOf(9)
                        color: Theme.accC

                        PanelText {
                            id: countText
                            anchors.centerIn: parent
                            text: String(card.count)
                            font.pixelSize: 11
                            color: Theme.accCFg
                        }
                    }
                }

                PanelText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Centre.ago(card.entries[0]?.when, card.now)
                    font.family: Theme.monoFamily
                    font.pixelSize: 11
                    color: Theme.mut
                }
            }

            Repeater {
                // By identity: an entry is the same object for as long as the
                // history keeps it, so a new one arriving adds a row rather
                // than rebuilding the card's -- and reloading their pictures,
                // which are not cached.
                model: ScriptModel {
                    values: card.expanded ? card.entries.slice(0, 8) : card.entries.slice(0, 1)
                    comparisonMode: ObjectComparison.Identity
                }

                // One notification in the card. A row around a Column rather
                // than a bare Column: a click has to land on the whole row --
                // the space beside the text included -- and a Column is only
                // as wide as what is in it once the handler is asked.
                NoteRow {
                    id: note

                    required property var modelData
                    required property int index

                    entry: note.modelData
                    tintInset: -6
                    onOpened: card.widget.closePopout()
                    width: body.width
                    height: lines.implicitHeight + 10

                    Column {
                        id: lines

                        y: 10
                        width: parent.width

                        Rectangle {
                            visible: note.index > 0
                            width: parent.width
                            height: 1
                            color: Theme.out
                        }

                        Item { visible: note.index > 0; width: 1; height: 8 }

                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: note.modelData.summary
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: note.modelData.urgency >= 2 ? Theme.error : Theme.fg
                        }

                        PanelText {
                            visible: note.modelData.body.length > 0
                            width: parent.width
                            topPadding: 3
                            text: note.modelData.body
                            wrapMode: Text.WordWrap
                            maximumLineCount: card.expanded ? 4 : 2
                            elide: Text.ElideRight
                            font.pixelSize: 13
                            lineHeight: 1.15
                            color: Theme.mut
                        }

                        NotePicture { source: note.picture }
                    }
                }
            }

            Row {
                visible: card.widget.askable || card.count > 1
                topPadding: 12
                spacing: 8

                TextButton {
                    visible: card.count > 1
                    text: card.expanded ? "Show less" : `${card.count - 1} more`
                    onActivated: card.expanded = !card.expanded
                }

                TextButton {
                    visible: card.widget.askable
                    glyph: "help"
                    iconName: "help-hint"
                    text: "Ask"
                    onActivated: card.widget.ask(card.entries[0])
                }
            }
        }
    }
}
