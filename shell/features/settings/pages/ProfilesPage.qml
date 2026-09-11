pragma ComponentBehavior: Bound

// Configuration profiles and per-output overrides.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.domain.config
import qs.domain.theme
import qs.ui.primitives

Column {
    id: root

    property var profiles: []
    readonly property string ctl: `${Quickshell.env("HOME")}/.local/bin/${Branding.slug}-ctl`

    spacing: 8
    Component.onCompleted: root.reload()

    function reload() {
        listProc.running = false;
        listProc.running = true;
    }

    readonly property Process _list: Process {
        id: listProc
        command: [root.ctl, "profile", "list"]
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
        runProc.command = [root.ctl].concat(args);
        runProc.running = true;
    }

    Repeater {
        model: root.profiles

        Rectangle {
            id: card
            required property var modelData

            width: root.width
            height: 46
            radius: 6
            color: card.modelData.active ? Theme.alpha(Theme.accent, 0.2)
                                         : Theme.backgroundAlternate

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 10

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 100

                    PanelText { text: card.modelData.name }
                    PanelText {
                        text: card.modelData.detail
                        font.pixelSize: 11
                        color: Theme.foregroundInactive
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !card.modelData.active
                    width: 70
                    height: 26
                    radius: 5
                    color: Theme.alpha(Theme.accent, useHover.hovered ? 0.4 : 0.25)

                    PanelText { anchors.centerIn: parent; text: "Use" }
                    HoverHandler { id: useHover }
                    TapHandler { onTapped: root.run(["profile", "use", card.modelData.name]) }
                }
            }
        }
    }

    PanelText {
        text: "Per-monitor overrides"
        font.pixelSize: 14
        topPadding: 10
    }

    PanelText {
        width: root.width
        wrapMode: Text.WordWrap
        font.pixelSize: 11
        color: Theme.foregroundInactive
        text: `Anything in the panel settings can differ per screen. Create a file named after the output in ${Paths.profileDir(ConfigStore.profile)}/monitors/, holding only the keys that differ.`
    }

    Repeater {
        model: Quickshell.screens

        Row {
            id: mon
            required property var modelData
            spacing: 10

            PanelText {
                width: 120
                text: mon.modelData.name
            }

            PanelText {
                color: Theme.foregroundInactive
                font.pixelSize: 11
                text: ConfigStore.monitorData[mon.modelData.name]
                    ? `${Object.keys(ConfigStore.monitorData[mon.modelData.name]).length} override group(s)`
                    : "no overrides"
            }
        }
    }
}
