pragma ComponentBehavior: Bound

// Shipped layouts.
//
// Applying one runs the same command the CLI does, so the two cannot diverge,
// and the previous profile is kept -- trying a layout must not be a one-way
// door.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.domain.theme
import qs.ui.primitives

CardGrid {
    id: root

    property var presets: []

    readonly property string ctl: `${Quickshell.env("HOME")}/.local/bin/${Branding.slug}-ctl`

    count: 1

    Component.onCompleted: root.reload()

    function reload() {
        listProc.running = false;
        listProc.running = true;
    }

    readonly property Process _list: Process {
        id: listProc
        command: [root.ctl, "preset", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                for (const line of text.split("\n")) {
                    if (line.trim().length === 0)
                        continue;
                    const m = line.match(/^(\S+)\s+(.*)$/);
                    if (m)
                        rows.push({ id: m[1], description: m[2] });
                }
                root.presets = rows;
            }
        }
    }

    readonly property Process _apply: Process { id: applyProc }

    function apply(id) {
        applyProc.running = false;
        applyProc.command = [root.ctl, "preset", "apply", id];
        applyProc.running = true;
    }

    Card {
        id: card

        width: root.cellWidth
        spacing: 8

        SectionLabel { text: "Shipped layouts" }

        PanelText {
            width: card.width - 2 * card.padding
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            lineHeight: 1.35
            text: "Applying a layout replaces your current panel configuration. The previous one is saved first, and the path is printed in the log."
        }

        Repeater {
            model: root.presets

            Rectangle {
                id: preset

                required property var modelData

                width: card.width - 2 * card.padding
                height: 58
                radius: Theme.radiusOf(12)
                color: presetHover.hovered ? Theme.hover : Theme.s1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 10

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - applyButton.width - parent.spacing
                        spacing: 1

                        PanelText {
                            text: preset.modelData.id
                            font.pixelSize: 14
                        }

                        PanelText {
                            text: preset.modelData.description
                            width: parent.width
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: Theme.mut
                        }
                    }

                    Rectangle {
                        id: applyButton

                        anchors.verticalCenter: parent.verticalCenter
                        width: 74
                        height: 30
                        radius: Theme.radiusOf(10)
                        color: applyHover.hovered ? Theme.acc : Theme.accC

                        PanelText {
                            anchors.centerIn: parent
                            text: "Apply"
                            font.pixelSize: 13
                            color: applyHover.hovered ? Theme.primaryFg : Theme.accCFg
                        }

                        HoverHandler { id: applyHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.apply(preset.modelData.id) }
                    }
                }

                HoverHandler { id: presetHover }
            }
        }

        PanelText {
            visible: root.presets.length === 0
            text: "No presets found."
            font.pixelSize: 13
            color: Theme.mut
        }
    }
}
