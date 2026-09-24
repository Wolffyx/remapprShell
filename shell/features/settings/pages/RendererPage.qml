pragma ComponentBehavior: Bound

// What draws the panel.
//
// This is a page rather than an enum row in the schema because changing the
// renderer is not a configuration write. It installs shell packages, generates
// an applet layout, switches plasmashell's shell package and can roll all three
// back -- so the button runs the same command the CLI does, and nothing here
// writes `panel.renderer` itself. A settings window that set the key directly
// would take our panel away and put nothing in its place.
//
// The compatibility matrix is shown before the switch, not after: the Plasma
// renderer is second-class by design, and a person choosing it deserves to see
// exactly which of their widgets it cannot draw.
//
// The list itself is the CLI's (`renderer list --json`), because it includes
// every other Quickshell configuration on the machine and only the CLI looks
// for them. Until it answers, or if it cannot, the three that always exist.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.config
import qs.domain.theme
import qs.domain.widgets
import qs.features.panel.model
import qs.ui.primitives

CardGrid {
    id: root

    readonly property string current: ConfigStore.value("panel.renderer", "quickshell")

    // Enabled entries only. A widget the user has already turned off is not
    // something they are about to lose.
    readonly property var enabledIds: (PanelModel.entries ?? [])
        .filter(e => e && e.enabled !== false && e.id)
        .map(e => e.id)

    property string status: ""
    property bool busy: false

    readonly property var builtin: [
        {
            id: "quickshell",
            label: "This shell",
            note: "Our own panel, drawn as a layer-shell surface. Every widget, and every visual effect."
        },
        {
            id: "plasma",
            label: "Plasma",
            note: "Drawn by plasmashell from this same configuration, using stock applets. No shaders, no blur, and any widget without a Plasma equivalent is left out."
        },
        {
            id: "none",
            label: "Nothing",
            note: "Your stock Plasma panels, exactly as they were. Nothing of ours is drawn."
        }
    ]
    property var discovered: []
    readonly property var options: root.discovered.length > 0 ? root.discovered : root.builtin

    readonly property Process _list: Process {
        id: listProc
        command: [Branding.ctlBin, "renderer", "list", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const rows = JSON.parse(text);
                    if (Array.isArray(rows) && rows.length > 0)
                        root.discovered = rows;
                } catch (e) {
                    Log.warn("settings", `renderer list did not parse: ${e}`);
                }
            }
        }
    }

    // Another Quickshell shell draws nothing of ours, so there is nothing of
    // ours for it to leave out.
    function isForeign(rendererId) {
        return rendererId.startsWith("quickshell:");
    }

    function unsupportedBy(rendererId) {
        if (root.isForeign(rendererId))
            return [];
        return WidgetRegistry.unsupportedBy(rendererId, root.enabledIds);
    }

    readonly property Process _switch: Process {
        id: switchProc
        onRunningChanged: {
            root.busy = running;
            if (!running) {
                root.status = "Done. If the panel has not changed, check: rmpr renderer status";
                listProc.running = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) root.status = text.trim().split("\n").pop()
        }
    }

    function apply(rendererId) {
        if (rendererId === root.current || root.busy)
            return;
        root.status = `Switching to ${rendererId}...`;
        switchProc.running = false;
        switchProc.command = [Branding.ctlBin, "renderer", "set", rendererId, "--yes"];
        switchProc.running = true;
    }

    Card {
        id: card

        width: root.cellWidth
        spacing: 8

        SectionLabel { text: "What draws the panel" }

        Repeater {
            model: root.options

            Rectangle {
                id: option

                required property var modelData

                // The CLI's answer once there is one: it reads the profile
                // the same way a switch would.
                readonly property bool active: root.discovered.length > 0
                                               ? option.modelData.current === true
                                               : option.modelData.id === root.current
                readonly property var missing: root.unsupportedBy(option.modelData.id)

                width: card.contentWidth
                height: body.implicitHeight + 20
                radius: Theme.radiusOf(12)
                color: option.active ? Theme.accC : Theme.s1

                Column {
                    id: body
                    x: 12
                    y: 10
                    width: parent.width - 24
                    spacing: 4

                    Row {
                        spacing: 8

                        PanelText {
                            text: option.modelData.label
                            font.pixelSize: 14
                            font.weight: option.active ? Font.Medium : Font.Normal
                            color: option.active ? Theme.accCFg : Theme.fg
                        }

                        PanelText {
                            visible: option.active
                            text: "in use"
                            color: option.active ? Theme.accCFg : Theme.mut
                            opacity: 0.7
                            font.pixelSize: 12
                        }
                    }

                    PanelText {
                        width: body.width
                        wrapMode: Text.WordWrap
                        text: option.modelData.note
                        color: option.active ? Theme.accCFg : Theme.mut
                        opacity: option.active ? 0.8 : 1
                        font.pixelSize: 12
                        lineHeight: 1.3
                    }

                    // Named individually rather than counted. "Some widgets are
                    // unsupported" is not something a person can act on.
                    PanelText {
                        visible: option.missing.length > 0
                        width: body.width
                        wrapMode: Text.WordWrap
                        text: `Will be left out: ${option.missing.join(", ")}`
                        color: option.active ? Theme.accCFg : Theme.mut
                        font.pixelSize: 12
                    }
                }

                HoverHandler { enabled: !option.active && !root.busy && !option.modelData.absent }
                TapHandler {
                    enabled: !option.active && !root.busy && !option.modelData.absent
                    onTapped: root.apply(option.modelData.id)
                }
            }
        }

        Hint {
            width: card.contentWidth
            text: "Only one of these draws a panel at a time. Switching takes a restore point first, and puts everything back if it does not work."
        }

        PanelText {
            visible: root.status.length > 0
            width: card.contentWidth
            wrapMode: Text.WordWrap
            text: root.status
            font.pixelSize: 12
        }
    }
}
