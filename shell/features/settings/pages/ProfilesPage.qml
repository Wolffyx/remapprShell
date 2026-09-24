pragma ComponentBehavior: Bound

// Configuration profiles and per-output overrides.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.domain.config
import qs.domain.theme
import qs.ui.primitives

CardGrid {
    id: root

    property var profiles: []

    count: 2

    Component.onCompleted: root.reload()

    function reload() {
        listProc.running = false;
        listProc.running = true;
    }

    readonly property Process _list: Process {
        id: listProc
        command: [Branding.ctlBin, "profile", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                for (const line of text.split("\n")) {
                    if (line.trim().length === 0)
                        continue;
                    const active = line.startsWith("*");
                    const m = line.slice(1).trim().match(/^(\S+)\s+(.*)$/);
                    if (m)
                        rows.push({ name: m[1], detail: m[2], active: active });
                }
                root.profiles = rows;
            }
        }
    }

    readonly property Process _run: Process {
        id: runProc
        onRunningChanged: if (!running) root.reload()
    }

    function run(args) {
        runProc.running = false;
        runProc.command = [Branding.ctlBin].concat(args);
        runProc.running = true;
    }

    Card {
        id: profileCard

        width: root.cellWidth
        spacing: 6

        SectionLabel { text: "Profiles" }

        Repeater {
            model: root.profiles

            Rectangle {
                id: profile

                required property var modelData

                width: profileCard.width - 2 * profileCard.padding
                height: 50
                radius: Theme.radiusOf(12)
                color: profile.modelData.active ? Theme.accC : Theme.s1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 10

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - use.width - parent.spacing
                        spacing: 1

                        PanelText {
                            text: profile.modelData.name
                            font.pixelSize: 14
                            color: profile.modelData.active ? Theme.accCFg : Theme.fg
                        }

                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: profile.modelData.detail
                            font.pixelSize: 12
                            color: profile.modelData.active ? Theme.accCFg : Theme.mut
                            opacity: profile.modelData.active ? 0.8 : 1
                        }
                    }

                    Rectangle {
                        id: use

                        anchors.verticalCenter: parent.verticalCenter
                        visible: !profile.modelData.active
                        width: visible ? 66 : 0
                        height: 28
                        radius: Theme.radiusOf(10)
                        color: useHover.hovered ? Theme.acc : Theme.accC

                        PanelText {
                            anchors.centerIn: parent
                            text: "Use"
                            font.pixelSize: 13
                            color: useHover.hovered ? Theme.primaryFg : Theme.accCFg
                        }

                        HoverHandler { id: useHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.run(["profile", "use", profile.modelData.name]) }
                    }
                }
            }
        }

        PanelText {
            visible: root.profiles.length === 0
            text: "No profiles found."
            font.pixelSize: 13
            color: Theme.mut
        }
    }

    Card {
        id: monitors

        width: root.cellWidth
        spacing: 8

        SectionLabel { text: "Per-monitor overrides" }

        PanelText {
            width: monitors.width - 2 * monitors.padding
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
            text: `Anything in the panel settings can differ per screen. Create a file named after the output in ${Paths.profileDir(ConfigStore.profile)}/monitors/, holding only the keys that differ.`
        }

        Repeater {
            model: Quickshell.screens

            Row {
                id: mon

                required property var modelData

                width: monitors.width - 2 * monitors.padding
                spacing: 10

                PanelText {
                    width: 120
                    text: mon.modelData.name
                    font.pixelSize: 13
                }

                PanelText {
                    color: Theme.mut
                    font.pixelSize: 12
                    text: ConfigStore.monitorData[mon.modelData.name]
                        ? `${Object.keys(ConfigStore.monitorData[mon.modelData.name]).length} override group(s)`
                        : "no overrides"
                }
            }
        }
    }
}
