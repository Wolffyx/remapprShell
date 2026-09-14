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
                    rows.push({
                        name: parts[0],
                        created: parts[1] ?? "",
                        paths: parts[2] ?? "",
                        size: parts[3] ?? "",
                        locked: t.indexOf("[locked]") >= 0
                    });
                }
                root.snapshots = rows;
            }
        }
    }

    // Pruning never takes the oldest, so the page does not offer to.
    readonly property string oldest: root.snapshots.length > 0
        ? root.snapshots.map(s => s.name).sort()[0] : ""

    // Restoring replaces configuration and cannot be undone, so it is asked
    // twice. One click used to do it, with `--yes` already on the command --
    // and restoring an old enough restore point is what removed a user's
    // profiles, from this page, in one click.
    property string armed: ""

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
            text: "Restore points are never removed when reverting or uninstalling. They are removed only here, or by pruning, which never takes a locked one or the oldest. Removing one is permanent."
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
                        width: parent.width - 150
                        spacing: 1

                        PanelText {
                            // A Text in a Column takes its width from its own
                            // content, so without this the name ran under the
                            // buttons and off the card.
                            width: parent.width
                            elide: Text.ElideRight
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

                    // Locked ones are never pruned. The oldest never is
                    // either, and cannot be unlocked into being, so it says
                    // so instead of offering a switch that changes nothing.
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: snap.modelData.name !== root.oldest
                        glyph: snap.modelData.locked ? "lock" : "lock_open"
                        iconName: snap.modelData.locked ? "object-locked" : "object-unlocked"
                        tooltip: snap.modelData.locked
                            ? "Locked: pruning will never remove this"
                            : "Lock this against pruning"
                        color: snap.modelData.locked ? Theme.acc : Theme.fg
                        onActivated: root.run(["snapshot",
                            snap.modelData.locked ? "unlock" : "lock", snap.modelData.name])
                    }

                    Item {
                        // Same footprint as the lock button it stands in for,
                        // so every row's buttons line up down the card.
                        anchors.verticalCenter: parent.verticalCenter
                        visible: snap.modelData.name === root.oldest
                        width: 34
                        height: 34

                        Glyph {
                            anchors.centerIn: parent
                            name: "lock"
                            fallback: "object-locked"
                            size: 17
                            color: Theme.acc
                        }
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: root.armed === snap.modelData.name ? "check" : "history"
                        iconName: "document-revert"
                        tooltip: root.armed === snap.modelData.name
                            ? "Click again to restore -- this replaces configuration and cannot be undone"
                            : "Restore this point"
                        color: root.armed === snap.modelData.name ? Theme.error : Theme.fg
                        onActivated: {
                            if (root.armed === snap.modelData.name) {
                                root.armed = "";
                                root.run(["restore", "--snapshot", snap.modelData.name, "--yes"]);
                            } else {
                                root.armed = String(snap.modelData.name);
                            }
                        }
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "edit-delete"
                        glyph: "delete"
                        tooltip: "Remove this restore point, permanently"
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
