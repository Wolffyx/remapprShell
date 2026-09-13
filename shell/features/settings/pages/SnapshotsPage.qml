pragma ComponentBehavior: Bound

// Restore points.
//
// Deletion is here because it must be somewhere a person can reach it, and
// nowhere else: nothing in this project removes a snapshot on its own. Every
// button on this page runs the same command the CLI does, rather than
// reimplementing the logic, so the two cannot drift apart.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

CardGrid {
    id: root

    property var snapshots: []
    property string status: ""

    readonly property string ctl: `${Quickshell.env("HOME")}/.local/bin/${Branding.slug}-ctl`

    count: 2

    Component.onCompleted: root.refresh()

    function refresh() {
        listProc.running = false;
        listProc.running = true;
    }

    readonly property Process _list: Process {
        id: listProc
        command: [root.ctl, "snapshot", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                for (const line of text.split("\n")) {
                    const t = line.trim();
                    if (t.length === 0 || t.startsWith("no snapshots"))
                        continue;
                    // "<name>  <created>  <n> path(s)  <size>"
                    const parts = t.split(/\s{2,}/);
                    rows.push({ name: parts[0], created: parts[1] ?? "", paths: parts[2] ?? "", size: parts[3] ?? "" });
                }
                root.snapshots = rows;
            }
        }
    }

    readonly property Process _run: Process {
        id: runProc
        onRunningChanged: if (!running) root.refresh()
    }

    function run(args) {
        runProc.running = false;
        runProc.command = [root.ctl].concat(args);
        runProc.running = true;
    }

    Card {
        id: take

        width: root.cellWidth
        spacing: 12

        SectionLabel { text: "Restore points" }

        Flow {
            width: take.width - 2 * take.padding
            spacing: 8

            TextButton {
                glyph: "history"
                iconName: "document-save"
                text: "Take one now"
                onActivated: root.run(["snapshot", "create", "manual"])
            }

            IconButton {
                iconName: "view-refresh"
                onActivated: root.refresh()
            }
        }

        PanelText {
            width: take.width - 2 * take.padding
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            lineHeight: 1.35
            text: "Restore points are never removed automatically -- not when reverting, not when uninstalling, not to save space. Removing one is permanent."
        }
    }

    Card {
        id: saved

        width: root.cellWidth
        spacing: 6

        SectionLabel { text: "Saved" }

        Repeater {
            model: root.snapshots

            Rectangle {
                id: snap

                required property var modelData

                width: saved.width - 2 * saved.padding
                height: 48
                radius: Theme.radiusOf(12)
                color: Theme.s1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 8

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 90
                        spacing: 1

                        PanelText {
                            text: snap.modelData.name
                            font.pixelSize: 14
                        }

                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: `${snap.modelData.created}   ${snap.modelData.paths}   ${snap.modelData.size}`
                            font.pixelSize: 12
                            color: Theme.mut
                        }
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "document-revert"
                        onActivated: root.run(["restore", "--snapshot", snap.modelData.name, "--yes"])
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "edit-delete"
                        onActivated: root.run(["snapshot", "remove", snap.modelData.name, "--yes"])
                    }
                }
            }
        }

        PanelText {
            visible: root.snapshots.length === 0
            text: "No restore points yet."
            font.pixelSize: 13
            color: Theme.mut
        }
    }
}
