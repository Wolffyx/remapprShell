pragma ComponentBehavior: Bound

// AI assist.
//
// A page rather than a plain list of keys, for two reasons. The provider list
// is what can actually run here -- one whose program is missing is shown with
// the reason rather than offered and then failing -- and the button at the
// bottom opens the consent window on a real report, which is the only honest
// way to show what "send" means.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.domain.config
import qs.domain.settings.groups
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

CardGrid {
    id: root

    readonly property bool assistOn: ConfigStore.value("ai.enabled", false) === true
    readonly property string provider: ConfigStore.value("ai.provider", "clipboard")

    property var providers: []
    readonly property var available: root.providers.filter(p => p.available).map(p => p.id)

    count: 3

    Component.onCompleted: listProc.running = true

    // The CLI is what decides availability, so this page and `rmpr ask
    // --providers` cannot disagree.
    readonly property Process _list: Process {
        id: listProc
        command: [Branding.ctlBin, "ask", "--providers", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.providers = JSON.parse(text); } catch (e) { root.providers = []; }
            }
        }
    }

    // Asked again once a change that decides availability has been written.
    // ConfigStore writes a quarter of a second after the last change, and the
    // CLI reads the file, so asking straight away gets yesterday's answer.
    readonly property Timer _relist: Timer {
        id: relist
        interval: 700
        onTriggered: { listProc.running = false; listProc.running = true; }
    }

    readonly property Process _forget: Process {
        id: forgetProc
        command: [Branding.ctlBin, "ask", "--forget"]
    }

    Card {
        id: what

        width: root.cellWidth
        spacing: 4

        SectionLabel { text: "Assist" }

        SettingRow {
            width: what.width - 2 * what.padding
            label: "AI assist"
            description: "Turns on the ask actions: in the notification history, as a global shortcut, and as `rmpr ask`. The notification listener runs while this is on."
            overridden: ConfigStore.isOverridden("ai.enabled")
            onResetRequested: ConfigStore.reset("ai.enabled")
            Toggle {
                checked: root.assistOn
                onToggled: value => ConfigStore.set("ai.enabled", value)
            }
        }

        SettingRow {
            width: what.width - 2 * what.padding
            label: "Provider"
            description: {
                const p = root.providers.find(x => x.id === root.provider);
                if (!p) return "Where a report goes.";
                if (!p.available) return `'${root.provider}' cannot run here: ${p.reason}.`;
                return p.leavesMachine
                    ? `'${root.provider}' sends the report off this machine, after you have seen it.`
                    : `'${root.provider}' keeps the report on this machine.`;
            }
            overridden: ConfigStore.isOverridden("ai.provider")
            onResetRequested: ConfigStore.reset("ai.provider")
            // Every provider, not only the usable ones: the two that need
            // setting up -- an Ollama address, a command -- are set up in the
            // card below once chosen, and could not be chosen otherwise.
            Select {
                readonly property var ids: root.providers.length > 0 ? root.providers.map(p => p.id) : [root.provider]
                values: ids
                labels: root.providers.map(p => p.available ? p.id : `${p.id} (not set up)`)
                currentIndex: Math.max(0, ids.indexOf(root.provider))
                onPicked: value => ConfigStore.set("ai.provider", value)
            }
        }

        PanelText {
            visible: root.providers.some(p => !p.available)
            width: what.width - 2 * what.padding
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            lineHeight: 1.35
            text: "Not available here: " + root.providers.filter(p => !p.available)
                .map(p => `${p.id} (${p.reason})`).join(", ")
        }
    }

    Card {
        id: providerCard

        width: root.cellWidth
        spacing: 4
        visible: root.provider === "ollama" || root.provider === "custom"

        SectionLabel { text: root.provider === "ollama" ? "Ollama" : "Custom command" }

        SettingRow {
            visible: root.provider === "ollama"
            width: providerCard.width - 2 * providerCard.padding
            label: "Address"
            description: "An address that is not this machine is confirmed like any other."
            overridden: ConfigStore.isOverridden("ai.ollamaUrl")
            onResetRequested: ConfigStore.reset("ai.ollamaUrl")
            TextInputRow {
                width: parent.width
                text: ConfigStore.value("ai.ollamaUrl", "http://127.0.0.1:11434")
                onCommitted: value => {
                    ConfigStore.set("ai.ollamaUrl", value);
                    relist.restart();
                }
            }
        }

        SettingRow {
            visible: root.provider === "ollama"
            width: providerCard.width - 2 * providerCard.padding
            label: "Model"
            description: "Empty picks the first model Ollama lists."
            overridden: ConfigStore.isOverridden("ai.ollamaModel")
            onResetRequested: ConfigStore.reset("ai.ollamaModel")
            TextInputRow {
                width: parent.width
                text: ConfigStore.value("ai.ollamaModel", "")
                onCommitted: value => ConfigStore.set("ai.ollamaModel", value)
            }
        }

        SettingRow {
            visible: root.provider === "custom"
            width: providerCard.width - 2 * providerCard.padding
            stacked: true
            label: "Command"
            description: "Run as written. %report becomes the redacted bundle's path; without it, the bundle arrives on standard input."
            overridden: ConfigStore.isOverridden("ai.command")
            onResetRequested: ConfigStore.reset("ai.command")
            TextInputRow {
                width: parent.width
                placeholderText: "my-tool --file %report"
                text: SettingGroups.formatList(ConfigStore.value("ai.command", []) ?? [], "words")
                onCommitted: value => {
                    ConfigStore.set("ai.command", SettingGroups.parseList(value, "words"));
                    relist.restart();
                }
            }
        }
    }

    Card {
        id: sending

        width: root.cellWidth
        spacing: 12

        SectionLabel { text: "What gets sent" }

        Flow {
            width: sending.width - 2 * sending.padding
            spacing: 8

            TextButton {
                glyph: "preview"
                iconName: "document-preview"
                text: "See what would be sent"
                onActivated: Quickshell.execDetached([Branding.ctlBin, "ask", "--review"])
            }

            TextButton {
                glyph: "lock_reset"
                iconName: "edit-undo"
                text: "Ask again before sending"
                onActivated: { forgetProc.running = false; forgetProc.running = true; }
            }
        }

        PanelText {
            width: sending.width - 2 * sending.padding
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            lineHeight: 1.35
            text: `Every report is written locally first and redacted there; 'rmpr report show' prints the same text a provider receives. A provider that sends off this machine asks once, showing the whole bundle, and remembers the answer until it is withdrawn here. Bind a key to ask about the last notification with: rmpr shortcuts set ask <key>`
        }
    }
}
