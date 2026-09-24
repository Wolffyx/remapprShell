pragma ComponentBehavior: Bound

// Shipped layouts.
//
// Applying one runs the same command the CLI does, so the two cannot diverge,
// and the previous profile is kept -- trying a layout must not be a one-way
// door.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

CardGrid {
    id: root

    property var presets: []

    Component.onCompleted: root.reload()

    function reload() {
        listProc.running = false;
        listProc.running = true;
    }

    readonly property Process _list: Process {
        id: listProc
        command: [Branding.ctlBin, "preset", "list"]
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
        applyProc.command = [Branding.ctlBin, "preset", "apply", id];
        applyProc.running = true;
    }

    Card {
        id: card

        width: root.cellWidth
        spacing: 8

        SectionLabel { text: "Shipped layouts" }

        Hint {
            width: card.contentWidth
            text: "Applying a layout replaces your current panel configuration. The previous one is saved first, and the path is printed in the log."
        }

        Repeater {
            model: root.presets

            OptionRow {
                id: preset

                required property var modelData

                width: card.contentWidth
                height: 58
                hoverable: true
                title: preset.modelData.id
                detail: preset.modelData.description

                TextButton {
                    tonal: true
                    width: 74
                    height: 30
                    radius: Theme.radiusOf(10)
                    text: "Apply"
                    onActivated: root.apply(preset.modelData.id)
                }
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
