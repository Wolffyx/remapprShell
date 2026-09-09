pragma ComponentBehavior: Bound

// Restore points.
//
// Deletion is here because it must be somewhere a person can reach it, and
// nowhere else: nothing in this project removes a snapshot on its own. Every
// button on this page runs the same command the CLI does, rather than
// reimplementing the logic, so the two cannot drift apart.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    property var snapshots: []
    property string status: ""

    readonly property string ctl: `${Branding.stateDir}/../../bin/${Branding.slug}-ctl`

    spacing: 8

    Component.onCompleted: root.refresh()

    function refresh() {
        listProc.running = false;
        listProc.running = true;
    }

    readonly property Process _list: Process {
        id: listProc
        command: [`${Quickshell.env("HOME")}/.local/bin/${Branding.slug}-ctl`, "snapshot", "list"]
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
        runProc.command = [`${Quickshell.env("HOME")}/.local/bin/${Branding.slug}-ctl`].concat(args);
        runProc.running = true;
    }

    Row {
        spacing: 8

        Rectangle {
            width: create.implicitWidth + 24
            height: 30
            radius: 6
            color: createHover.hovered ? PlasmaColors.hoverBackground : PlasmaColors.backgroundAlternate

            PanelText {
                id: create
                anchors.centerIn: parent
                text: "Take a restore point now"
            }

            HoverHandler { id: createHover }
            TapHandler { onTapped: root.run(["snapshot", "create", "manual"]) }
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "view-refresh"
            onActivated: root.refresh()
        }
    }

    PanelText {
        width: root.width
        wrapMode: Text.WordWrap
        color: PlasmaColors.foregroundInactive
        font.pixelSize: 11
        text: "Restore points are never removed automatically -- not when reverting, not when uninstalling, not to save space. Removing one is permanent."
    }

    Repeater {
        model: root.snapshots

        Rectangle {
            id: snap

            required property var modelData

            width: root.width
            height: 44
            radius: 6
            color: PlasmaColors.backgroundAlternate

            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 10

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 90

                    PanelText { text: snap.modelData.name }

                    PanelText {
                        text: `${snap.modelData.created}   ${snap.modelData.paths}   ${snap.modelData.size}`
                        font.pixelSize: 11
                        color: PlasmaColors.foregroundInactive
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
        color: PlasmaColors.foregroundInactive
    }
}
