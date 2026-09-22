pragma ComponentBehavior: Bound

// Version, paths, and where things live.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.config
import qs.domain.theme
import qs.domain.launcher
import qs.domain.widgets
import qs.ui.primitives
import qs.ui.controls

CardGrid {
    id: root

    count: 2

    property string updateStatus: ""
    property bool checking: false

    // Only a check. Applying an update rewrites the installed copy -- or, for
    // a checkout, the working tree -- so that stays a command somebody types.
    readonly property Process _check: Process {
        id: checkProc
        command: [Branding.ctlBin, "update", "--check"]
        onRunningChanged: root.checking = running
        stdout: StdioCollector { id: checkOut }
        stderr: StdioCollector { id: checkErr }
        onExited: code => {
            const lines = (checkErr.text + "\n" + checkOut.text).split("\n")
                .map(l => l.replace(/^==> /, "").trim()).filter(l => l.length > 0);
            root.updateStatus = code === 0 ? lines.join("\n") : `The check failed: ${lines.pop() ?? `exit ${code}`}`;
        }
    }

    Card {
        id: what

        width: root.cellWidth
        spacing: 6

        SectionLabel { text: "This shell" }

        PanelText {
            text: `${Branding.displayName} ${Branding.version}`
            font.pixelSize: 18
            font.weight: Font.Medium
        }

        PanelText {
            width: what.width - 2 * what.padding
            wrapMode: Text.WordWrap
            text: "A configurable desktop shell for KDE Plasma."
            font.pixelSize: 13
            color: Theme.mut
        }

        PanelText {
            text: "quickshell · wayland"
            font.family: Theme.monoFamily
            font.pixelSize: 12
            color: Theme.mut
        }
    }

    Card {
        id: where

        width: root.cellWidth
        spacing: 8

        SectionLabel { text: "Where things live" }

        Repeater {
            model: [
                { label: "Configuration",  value: Branding.configDir },
                { label: "Shell",          value: Branding.qsConfigDir },
                { label: "State",          value: Branding.stateDir },
                { label: "Widgets",        value: `${Object.keys(WidgetRegistry.all).length} installed` },
                { label: "Menu opens",     value: LauncherService.appsProvider.providerId },
                { label: "Search opens",   value: LauncherService.searchProvider.providerId }
            ]

            // The label above the value rather than beside it: a path is as
            // long as it is, and a column wide enough for the longest one
            // leaves the short ones stranded.
            Column {
                id: line

                required property var modelData

                width: where.width - 2 * where.padding
                spacing: 1

                PanelText {
                    text: line.modelData.label
                    font.pixelSize: 12
                    color: Theme.mut
                }

                PanelText {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: line.modelData.value
                    font.family: Theme.monoFamily
                    font.pixelSize: 12
                }
            }
        }
    }

    Card {
        id: updates

        width: root.cellWidth
        spacing: 4

        SectionLabel { text: "Updates" }

        SettingRow {
            width: updates.width - 2 * updates.padding
            label: "Follow"
            description: ConfigStore.value("update.channel", "main") === "dev"
                ? "dev: where work lands, every day."
                : "main: moves on a release."
            overridden: ConfigStore.isOverridden("update.channel")
            onResetRequested: ConfigStore.reset("update.channel")
            Select {
                values: ["main", "dev"]
                labels: ["Releases", "Everything as it lands"]
                currentIndex: ConfigStore.value("update.channel", "main") === "dev" ? 1 : 0
                onPicked: value => ConfigStore.set("update.channel", value)
            }
        }

        SettingRow {
            width: updates.width - 2 * updates.padding
            stacked: true
            label: "Update from"
            description: "A git URL. Empty uses this checkout's own origin."
            overridden: ConfigStore.isOverridden("update.remote")
            onResetRequested: ConfigStore.reset("update.remote")
            TextInputRow {
                width: parent.width
                placeholderText: "git@github.com:you/fork.git"
                text: ConfigStore.value("update.remote", "") ?? ""
                onCommitted: value => ConfigStore.set("update.remote", value.trim())
            }
        }

        SettingRow {
            width: updates.width - 2 * updates.padding
            stacked: true
            label: "Or from a checkout here"
            description: "A path on this machine, which wins over the URL -- for trying a change before it is pushed."
            overridden: ConfigStore.isOverridden("update.localSource")
            onResetRequested: ConfigStore.reset("update.localSource")
            TextInputRow {
                width: parent.width
                placeholderText: `~/src/${Branding.slug}`
                text: ConfigStore.value("update.localSource", "") ?? ""
                onCommitted: value => ConfigStore.set("update.localSource", value.trim())
            }
        }

        Flow {
            width: updates.width - 2 * updates.padding
            spacing: 8
            TextButton {
                enabled: !root.checking
                iconName: "view-refresh"
                glyph: "update"
                text: root.checking ? "Checking..." : "Check for updates"
                onActivated: { checkProc.running = false; checkProc.running = true; }
            }
        }

        PanelText {
            visible: root.updateStatus.length > 0
            width: updates.width - 2 * updates.padding
            wrapMode: Text.WordWrap
            font.family: Theme.monoFamily
            font.pixelSize: 12
            text: root.updateStatus
        }

        PanelText {
            width: updates.width - 2 * updates.padding
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            text: "Nothing is installed from here. To take an update: rmpr update -- and rmpr update --rollback puts the last one back."
        }
    }
}
