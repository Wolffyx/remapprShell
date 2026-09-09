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

Column {
    id: root

    property var presets: []

    readonly property string ctl: `${Quickshell.env("HOME")}/.local/bin/${Branding.slug}-ctl`

    spacing: 8

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

    PanelText {
        width: root.width
        wrapMode: Text.WordWrap
        color: PlasmaColors.foregroundInactive
        font.pixelSize: 11
        text: "Applying a layout replaces your current panel configuration. The previous one is saved first, and the path is printed in the log."
    }

    Repeater {
        model: root.presets

        Rectangle {
            id: card

            required property var modelData

            width: root.width
            height: 56
            radius: 6
            color: cardHover.hovered ? PlasmaColors.hoverBackground : PlasmaColors.backgroundAlternate

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 10

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 90

                    PanelText {
                        text: card.modelData.id
                        font.pixelSize: 14
                    }

                    PanelText {
                        text: card.modelData.description
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: PlasmaColors.foregroundInactive
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 70
                    height: 28
                    radius: 5
                    color: PlasmaColors.alpha(PlasmaColors.accent, applyHover.hovered ? 0.4 : 0.25)

                    PanelText {
                        anchors.centerIn: parent
                        text: "Apply"
                    }

                    HoverHandler { id: applyHover }
                    TapHandler { onTapped: root.apply(card.modelData.id) }
                }
            }

            HoverHandler { id: cardHover }
        }
    }

    PanelText {
        visible: root.presets.length === 0
        text: "No presets found."
        color: PlasmaColors.foregroundInactive
    }
}
