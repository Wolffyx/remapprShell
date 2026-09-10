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

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.config
import qs.domain.theme
import qs.domain.widgets
import qs.features.panel.model
import qs.ui.primitives

Column {
    id: root

    readonly property string current: ConfigStore.value("panel.renderer", "quickshell")

    // Enabled entries only. A widget the user has already turned off is not
    // something they are about to lose.
    readonly property var enabledIds: (PanelModel.entries ?? [])
        .filter(e => e && e.enabled !== false && e.id)
        .map(e => e.id)

    property string status: ""
    property bool busy: false

    readonly property var options: [
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
            id: "caelestia",
            label: "caelestia",
            note: "caelestia's own bar, started as a service. None of its code runs inside this shell."
        },
        {
            id: "none",
            label: "Nothing",
            note: "Your stock Plasma panels, exactly as they were. Nothing of ours is drawn."
        }
    ]

    spacing: 8

    function unsupportedBy(rendererId) {
        return WidgetRegistry.unsupportedBy(rendererId, root.enabledIds);
    }

    readonly property Process _switch: Process {
        id: switchProc
        onRunningChanged: {
            root.busy = running;
            if (!running)
                root.status = "Done. If the panel has not changed, check: rmpr renderer status";
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

    Repeater {
        model: root.options

        Rectangle {
            id: option

            required property var modelData

            readonly property bool active: option.modelData.id === root.current
            readonly property var missing: root.unsupportedBy(option.modelData.id)

            width: root.width
            height: body.implicitHeight + 20
            radius: 6
            color: option.active ? PlasmaColors.hoverBackground : PlasmaColors.backgroundAlternate

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
                        font.bold: option.active
                    }

                    PanelText {
                        visible: option.active
                        text: "in use"
                        color: PlasmaColors.foregroundInactive
                        font.pixelSize: 11
                    }
                }

                PanelText {
                    width: body.width
                    wrapMode: Text.WordWrap
                    text: option.modelData.note
                    color: PlasmaColors.foregroundInactive
                    font.pixelSize: 11
                }

                // Named individually rather than counted. "Some widgets are
                // unsupported" is not something a person can act on.
                PanelText {
                    visible: option.missing.length > 0
                    width: body.width
                    wrapMode: Text.WordWrap
                    text: `Will be left out: ${option.missing.join(", ")}`
                    color: PlasmaColors.foregroundInactive
                    font.pixelSize: 11
                }
            }

            HoverHandler { enabled: !option.active && !root.busy }
            TapHandler {
                enabled: !option.active && !root.busy
                onTapped: root.apply(option.modelData.id)
            }
        }
    }

    PanelText {
        width: root.width
        wrapMode: Text.WordWrap
        color: PlasmaColors.foregroundInactive
        font.pixelSize: 11
        text: "Only one of these draws a panel at a time. Switching takes a restore point first, and puts everything back if it does not work."
    }

    PanelText {
        visible: root.status.length > 0
        width: root.width
        wrapMode: Text.WordWrap
        text: root.status
        font.pixelSize: 11
    }
}
