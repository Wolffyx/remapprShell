pragma ComponentBehavior: Bound

// Appearance: the Qt style applications are drawn in, and which parts of this
// shell's own theme are installed.
//
// Both go through `theme`, the command the CLI has. A style is a single
// ledgered key with an undo of its own. Installing the theme's parts runs a
// plain `theme apply`, which takes a restore point first and changes no
// colours, icons or style -- that is `--appearance`, and this page does not
// offer it. A style that is not installed is shown with the command that
// installs it, for a person to run: nothing here installs a package.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.kde
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    // `theme status --json`, parsed. Null until the first read returns.
    property var themeState: null
    property string status: ""
    property bool busy: false

    readonly property var styles: root.themeState?.styles ?? []
    readonly property var parts: root.themeState?.parts ?? ({})

    // The parts a plain apply would add, named as a person would.
    readonly property var missing: {
        if (!root.themeState)
            return [];
        const out = [];
        if (!root.themeState.package)
            out.push("the look-and-feel package");
        if ((root.parts.schemes ?? 0) === 0)
            out.push("the colour schemes");
        if (!root.parts.switcher)
            out.push("the Alt+Tab switcher");
        if (!root.parts.desktoptheme)
            out.push("the Plasma theme");
        if (!root.parts.splash)
            out.push("the splash");
        return out;
    }

    spacing: 10

    Component.onCompleted: root.refresh()

    function refresh() {
        readProc.running = false;
        readProc.running = true;
    }

    function run(args) {
        if (root.busy)
            return;
        root.status = "";
        runProc.command = [Branding.ctlBin, "theme"].concat(args);
        runProc.running = true;
    }

    readonly property Process _read: Process {
        id: readProc
        command: [Branding.ctlBin, "theme", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themeState = JSON.parse(text);
                } catch (e) {
                    root.status = "Could not read the theme's state.";
                    Log.warn("settings", `theme status: ${e}`);
                }
            }
        }
    }

    readonly property Process _run: Process {
        id: runProc
        onRunningChanged: {
            root.busy = running;
            if (!running)
                root.refresh();
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const errors = text.split("\n").filter(l => /error/i.test(l));
                if (errors.length > 0)
                    root.status = errors.pop().replace(/^.*error:?\s*/i, "");
            }
        }
    }

    PanelText {
        text: "Application style"
        font.pixelSize: 13
    }

    Flow {
        width: root.width
        spacing: 6
        enabled: !root.busy

        Repeater {
            model: root.styles

            TextButton {
                required property var modelData

                text: modelData.key.charAt(0).toUpperCase() + modelData.key.slice(1)
                checked: modelData.id === (root.themeState?.style ?? "")
                enabled: modelData.installed
                opacity: modelData.installed ? 1 : 0.45
                onActivated: if (!checked) root.run(["style", modelData.id])
            }
        }
    }

    PanelText {
        width: root.width
        wrapMode: Text.WordWrap
        color: PlasmaColors.foregroundInactive
        font.pixelSize: 11
        text: {
            const s = root.styles.find(x => x.id === root.themeState?.style);
            const what = s ? `${s.key}: ${s.label}. ` : "";
            return `${what}KDE applications already open change at once; others when next started.`;
        }
    }

    Repeater {
        model: root.styles.filter(s => !s.installed)

        PanelText {
            required property var modelData

            width: root.width
            wrapMode: Text.WordWrap
            color: PlasmaColors.foregroundInactive
            font.pixelSize: 11
            text: modelData.install.length > 0
                ? `${modelData.key} is not installed. In a terminal: ${modelData.install}`
                : `${modelData.key} is not installed.`
        }
    }

    Item { width: 1; height: 6 }

    PanelText {
        text: `${Branding.displayName}'s theme`
        font.pixelSize: 13
    }

    PanelText {
        width: root.width
        wrapMode: Text.WordWrap
        color: PlasmaColors.foregroundInactive
        font.pixelSize: 11
        text: {
            if (!root.themeState)
                return "";
            const state = root.themeState.active ? "Its look-and-feel package is active."
                        : root.themeState.package ? "Its look-and-feel package is installed but not active."
                        : "Not installed.";
            const gaps = root.missing.length > 0 ? ` Missing: ${root.missing.join(", ")}.` : " Every part is installed.";
            return state + gaps;
        }
    }

    TextButton {
        visible: root.missing.length > 0
        enabled: !root.busy
        iconName: "run-install"
        text: root.themeState?.package ? "Install the missing parts" : "Install the theme"
        onActivated: root.run(["apply"])
    }

    PanelText {
        visible: root.missing.length > 0
        width: root.width
        wrapMode: Text.WordWrap
        color: PlasmaColors.foregroundInactive
        font.pixelSize: 11
        text: "A restore point is taken first. Your colours, icons and style are left as they are; the new parts appear in System Settings for you to choose."
    }

    Row {
        spacing: 8
        enabled: !root.busy

        TextButton {
            visible: root.themeState?.styleCustomised ?? false
            iconName: "edit-undo"
            text: "Undo the style"
            onActivated: root.run(["style", "revert"])
        }

        TextButton {
            iconName: "configure"
            text: "Plasma's application style settings"
            onActivated: PlasmaApplets.openSettings("kcm_style")
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "view-refresh"
            onActivated: root.refresh()
        }
    }

    PanelText {
        visible: root.status.length > 0
        width: root.width
        wrapMode: Text.WordWrap
        text: root.status
        font.pixelSize: 11
    }
}
