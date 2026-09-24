pragma ComponentBehavior: Bound

// One day of the notification centre's stream: the day's name, and a row for
// each notification that arrived on it.

import QtQuick
import Quickshell
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: bucket

    // The bell: whether Ask is offered and what it does, and the popout that
    // opening a notification puts away.
    required property var widget

    // { label, entries }, from Centre.buckets.
    required property var day

    MenuTitle {
        leftPadding: 0
        text: bucket.day.label
    }

    Repeater {
        // By identity, as in a group card.
        model: ScriptModel {
            values: bucket.day.entries
            comparisonMode: ObjectComparison.Identity
        }

        NoteRow {
            id: line

            required property var modelData
            required property int index

            entry: line.modelData
            tintInset: 2
            onOpened: bucket.widget.closePopout()
            width: bucket.width
            height: lineBody.implicitHeight + 24

            NoteIcon {
                y: 13
                size: 20
                source: line.modelData.appIcon ?? ""
            }

            Column {
                id: lineBody
                x: 34
                y: 12
                width: parent.width - 34

                Item {
                    width: parent.width
                    height: summary.implicitHeight

                    PanelText {
                        id: summary
                        width: parent.width - stamp.width - 8
                        elide: Text.ElideRight
                        text: line.modelData.summary
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: line.modelData.urgency >= 2 ? Theme.error : Theme.fg
                    }

                    PanelText {
                        id: stamp
                        anchors.right: parent.right
                        text: Qt.formatDateTime(new Date(line.modelData.when), "HH:mm")
                        font.family: Theme.monoFamily
                        font.pixelSize: 11
                        color: Theme.mut
                    }
                }

                PanelText {
                    visible: line.modelData.body.length > 0
                    width: parent.width
                    topPadding: 2
                    text: line.modelData.body
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.pixelSize: 13
                    color: Theme.mut
                }

                // The picture it is about, as in the grouped view, a little
                // lower.
                NotePicture {
                    source: line.picture
                    pictureHeight: 100
                    sourceSize: Qt.size(760, 300)
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.out
                visible: line.index < bucket.day.entries.length - 1
            }

            IconButton {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                visible: bucket.widget.askable && line.hovered
                size: 30
                glyph: "help"
                iconName: "help-hint"
                onActivated: bucket.widget.ask(line.modelData)
            }
        }
    }
}
