pragma ComponentBehavior: Bound

// Configuration profiles and per-output overrides.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.domain.config
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

CardGrid {
    id: root

    property var profiles: []

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

            OptionRow {
                id: profile

                required property var modelData

                width: profileCard.contentWidth
                height: 50
                title: profile.modelData.name
                detail: profile.modelData.detail
                selected: profile.modelData.active

                TextButton {
                    visible: !profile.modelData.active
                    tonal: true
                    width: 66
                    height: 28
                    radius: Theme.radiusOf(10)
                    text: "Use"
                    onActivated: root.run(["profile", "use", profile.modelData.name])
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

        Hint {
            width: monitors.contentWidth
            text: `Anything in the panel settings can differ per screen. Create a file named after the output in ${Paths.profileDir(ConfigStore.profile)}/monitors/, holding only the keys that differ.`
        }

        Repeater {
            model: Quickshell.screens

            Row {
                id: mon

                required property var modelData

                width: monitors.contentWidth
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
