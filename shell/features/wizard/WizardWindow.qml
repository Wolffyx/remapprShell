pragma ComponentBehavior: Bound

// The first-run wizard.
//
// It asks five things, writes them, and gets out of the way. Everything it sets
// is reachable afterwards from the settings window, so nothing here is a
// one-way door and every step can be skipped.
//
// Two rules it follows:
//
//   * A preset REPLACES the profile, so it is applied first and the other
//     answers are written on top of it. The other order would have the preset
//     quietly discard the position the user just picked.
//   * Choosing a renderer other than this one is a change to KDE's own
//     configuration, not a config write, so it runs the same command the CLI
//     does -- restore point, verification and rollback included -- and says so
//     on screen before it does.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.platform.system
import qs.domain.config
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

FloatingWindow {
    id: root

    signal finished

    readonly property int stepCount: 7
    property int step: 0

    // Answers, held until Finish. Nothing is written while the user is still
    // deciding: a wizard that applied each answer as it was given would leave a
    // half-configured shell behind if it were closed halfway through.
    property string position: ConfigStore.value("panel.position", "bottom")
    property int thickness: ConfigStore.value("panel.thickness", 40)
    property string preset: ""
    property string launcher: ConfigStore.value("launcher.provider", "auto")
    property string renderer: "quickshell"

    // What this shell's theme is allowed to change outside itself. The whole
    // desktop by default, so the panel and the applications under it agree;
    // every part can be left out, and one left out keeps whatever System
    // Settings says. The same names the settings window and `theme status`
    // use.
    property bool themeDesktop: ConfigStore.value("theme.desktop.enabled", true) === true
    readonly property var themeParts: [
        { key: "colours",     label: "Colour scheme",        sub: "The colours every Qt application is drawn with." },
        { key: "icons",       label: "Icon theme",           sub: "Applications, and the shell's own icons." },
        { key: "style",       label: "Widget style",         sub: "Buttons, scrollbars, checkboxes." },
        { key: "plasmaTheme", label: "Plasma desktop theme", sub: "Plasma's own surfaces." },
        { key: "decorations", label: "Window decorations",   sub: "Titlebars and borders." },
        { key: "switcher",    label: "Alt+Tab switcher",     sub: "The window switcher's layout." }
    ]
    property var themeWanted: ({ colours: true, icons: true, style: true,
                                 plasmaTheme: true, decorations: true, switcher: true })
    // "off", or a provider id. Off by default: nothing about a shell needs an
    // assistant, and a wizard that pre-ticked it would be choosing for people.
    property string ai: "off"
    property var aiProviders: []

    property var presets: []
    property string status: ""

    title: `Welcome to ${Branding.displayName}`
    implicitWidth: 640
    implicitHeight: 460
    color: Theme.background

    Component.onCompleted: {
        presetsProc.running = true;
        providersProc.running = true;
    }

    // Detected rather than listed: a provider whose program is not installed
    // is not offered, so the answer "claude-code" cannot be given on a
    // machine where it would fail.
    readonly property Process _providers: Process {
        id: providersProc
        command: [Branding.ctlBin, "ask", "--providers", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.aiProviders = JSON.parse(text).filter(p => p.available).map(p => p.id);
                } catch (e) {
                    root.aiProviders = [];
                }
            }
        }
    }

    // The preset list comes from the CLI rather than a directory listing: it
    // already merges the shipped presets with the user's own, and duplicating
    // that here would mean two answers to "what presets exist".
    readonly property Process _presets: Process {
        id: presetsProc
        command: [Branding.ctlBin, "preset", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                for (const line of text.split("\n")) {
                    const name = line.trim().split(/\s+/)[0];
                    if (name && name !== "no")
                        names.push(name);
                }
                root.presets = names;
            }
        }
    }

    readonly property Process _apply: Process {
        id: applyProc
        onRunningChanged: if (!running) root._afterPreset()
    }

    function _afterPreset() {
        // Written after the preset has landed, so these win over it.
        ConfigStore.set("panel.position", root.position);
        ConfigStore.set("panel.thickness", root.thickness);
        ConfigStore.set("launcher.provider", root.launcher);
        ConfigStore.set("ai.enabled", root.ai !== "off");
        if (root.ai !== "off")
            ConfigStore.set("ai.provider", root.ai);

        ConfigStore.set("theme.desktop.enabled", root.themeDesktop);
        for (const part of root.themeParts)
            ConfigStore.set(`theme.desktop.${part.key}`, root.themeWanted[part.key] !== false);

        if (root.renderer !== "quickshell") {
            root.status = `Switching to the ${root.renderer} renderer...`;
            // Detached, and not a Process owned by this window. `_markDone`
            // below ends with `finished()`, which the LazyLoader in shell.qml
            // answers by destroying this window -- and a Process destroyed in
            // the same turn it is told to start never spawns anything, quietly.
            // The renderer the wizard was asked for was never switched to.
            Quickshell.execDetached([Branding.ctlBin, "renderer", "set", root.renderer, "--yes"]);
        }

        root._markDone();
    }

    function finish() {
        root.status = "Applying...";
        if (root.preset.length > 0) {
            applyProc.command = [Branding.ctlBin, "preset", "apply", root.preset];
            applyProc.running = true;   // _afterPreset runs when it exits
        } else {
            root._afterPreset();
        }
    }

    function skip() {
        // Skipping still marks the wizard done. Showing it again on the next
        // start would be the same as not having a skip button.
        root._markDone();
    }

    function _markDone() {
        Fs.ensureDir(Paths.stateDir);
        doneView.setText(`${Branding.version}\n`);
        Log.info("wizard", "finished");
        root.finished();
    }

    readonly property FileView _done: FileView {
        id: doneView
        path: Paths.wizardDoneFile
        atomicWrites: true
        printErrors: false
    }

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        PanelText {
            text: [`Welcome`, `Where should the panel go?`, `Pick a layout`,
                   `What opens when you press the start button?`,
                   `What should draw the panel?`,
                   `When something breaks, ask an assistant?`,
                   `What should the theme change?`][root.step] ?? ""
            font.pixelSize: 20
        }

        // ---- 0: welcome
        Column {
            visible: root.step === 0
            width: parent.width
            spacing: 8

            PanelText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: `${Branding.displayName} draws a panel and rethemes Plasma's own components. It does not replace your notifications, lock screen, wallpaper or task switcher -- Plasma already has those, and they keep working.`
            }

            PanelText {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.foregroundInactive
                text: "Nothing is written until the last step, and everything here can be changed afterwards in settings."
            }
        }

        // ---- 1: panel
        Column {
            visible: root.step === 1
            width: parent.width
            spacing: 6

            SettingRow {
                width: parent.width
                label: "Position"
                Select {
                    values: ["bottom", "top", "left", "right"]
                    currentIndex: Math.max(0, ["bottom", "top", "left", "right"].indexOf(root.position))
                    onPicked: value => root.position = value
                }
            }

            SettingRow {
                width: parent.width
                label: "Thickness"
                NumberSlider {
                    width: parent.width
                    from: 20
                    to: 96
                    stepSize: 2
                    value: root.thickness
                    onMoved: value => root.thickness = Math.round(value)
                }
            }
        }

        // ---- 2: preset
        Column {
            visible: root.step === 2
            width: parent.width
            spacing: 6

            PanelText {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.foregroundInactive
                text: "A layout replaces your current configuration. Your existing one is kept, and 'preset apply' can be undone from the Layouts page."
            }

            SettingRow {
                width: parent.width
                label: "Layout"
                Select {
                    values: ["keep what I have"].concat(root.presets)
                    currentIndex: 0
                    onPicked: value => root.preset = (value === "keep what I have" ? "" : value)
                }
            }
        }

        // ---- 3: launcher
        Column {
            visible: root.step === 3
            width: parent.width
            spacing: 6

            SettingRow {
                width: parent.width
                label: "Application menu"
                description: "Kickoff is Plasma's own menu. The built-in one is ours. Either can be changed later."
                Select {
                    values: ["auto", "kickoff", "builtin", "krunner"]
                    currentIndex: Math.max(0, ["auto", "kickoff", "builtin", "krunner"].indexOf(root.launcher))
                    onPicked: value => root.launcher = value
                }
            }
        }

        // ---- 4: renderer
        Column {
            visible: root.step === 4
            width: parent.width
            spacing: 6

            SettingRow {
                width: parent.width
                label: "Drawn by"
                description: "Plasma's panel is drawn from this same configuration, but with stock applets only."
                Select {
                    values: ["quickshell", "plasma"]
                    currentIndex: root.renderer === "plasma" ? 1 : 0
                    onPicked: value => root.renderer = value
                }
            }

            PanelText {
                visible: root.renderer !== "quickshell"
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.foregroundInactive
                text: "This one changes KDE's own settings. A restore point is taken first, and it is put back automatically if the switch does not work."
            }
        }

        // ---- 5: AI assist
        Column {
            visible: root.step === 5
            width: parent.width
            spacing: 6

            SettingRow {
                width: parent.width
                label: "AI assist"
                description: "Hands a redacted diagnostic report to an assistant, on request. Nothing leaves this machine without showing you exactly what would go."
                Select {
                    values: ["off"].concat(root.aiProviders)
                    currentIndex: Math.max(0, ["off"].concat(root.aiProviders).indexOf(root.ai))
                    onPicked: value => root.ai = value
                }
            }
        }

        // ---- 6: what the theme changes
        Column {
            visible: root.step === 6
            width: parent.width
            spacing: 6

            PanelText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: `Choosing ${Branding.displayName}'s theme can retheme KDE itself, so applications match the shell rather than only the panel. Every key is recorded, and \`${Branding.shortName} theme revert\` puts all of it back.`
            }

            ToggleRow {
                label: "Theme the whole desktop"
                description: "Off confines the theme to what this shell draws."
                checked: root.themeDesktop
                onToggled: value => root.themeDesktop = value
            }

            Column {
                width: parent.width
                opacity: root.themeDesktop ? 1 : 0.45
                enabled: root.themeDesktop

                Repeater {
                    model: root.themeParts

                    delegate: ToggleRow {
                        required property var modelData
                        label: modelData.label
                        description: modelData.sub
                        checked: root.themeWanted[modelData.key] !== false
                        onToggled: value => {
                            const next = Object.assign({}, root.themeWanted);
                            next[modelData.key] = value;
                            root.themeWanted = next;
                        }
                    }
                }
            }

            PanelText {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.foregroundInactive
                text: root.aiProviders.length === 0
                    ? "No provider was found on this machine. The clipboard one needs wl-copy; claude-code needs the claude command."
                    : "The clipboard provider copies the report and sends nothing. The others are named after the program they run, and were found here."
            }
        }

        PanelText {
            visible: root.status.length > 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.status
            font.pixelSize: 11
        }
    }

    // Navigation, pinned to the bottom so it does not move as steps change
    // height.
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 8

        Rectangle {
            width: skipText.implicitWidth + 24
            height: 30
            radius: 6
            color: skipHover.hovered ? Theme.hoverBackground : "transparent"

            PanelText {
                id: skipText
                anchors.centerIn: parent
                text: "Skip"
                color: Theme.foregroundInactive
            }

            HoverHandler { id: skipHover }
            TapHandler { onTapped: root.skip() }
        }

        Rectangle {
            visible: root.step > 0
            width: backText.implicitWidth + 24
            height: 30
            radius: 6
            color: backHover.hovered ? Theme.hoverBackground : Theme.backgroundAlternate

            PanelText { id: backText; anchors.centerIn: parent; text: "Back" }

            HoverHandler { id: backHover }
            TapHandler { onTapped: root.step = Math.max(0, root.step - 1) }
        }

        Rectangle {
            width: nextText.implicitWidth + 24
            height: 30
            radius: 6
            color: nextHover.hovered ? Theme.hoverBackground : Theme.backgroundAlternate

            PanelText {
                id: nextText
                anchors.centerIn: parent
                text: root.step === root.stepCount - 1 ? "Finish" : "Next"
            }

            HoverHandler { id: nextHover }
            TapHandler {
                onTapped: {
                    if (root.step === root.stepCount - 1)
                        root.finish();
                    else
                        root.step++;
                }
            }
        }
    }

    PanelText {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        text: `${root.step + 1} of ${root.stepCount}`
        color: Theme.foregroundInactive
        font.pixelSize: 11
    }
}
