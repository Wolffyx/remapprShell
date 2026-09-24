pragma ComponentBehavior: Bound

// Taskbar: the panel itself, and the widgets that are really parts of it --
// the clock, the workspace pills, the window buttons.
//
// Every control here writes one configuration key, the same keys the
// reference documents and the same ones a profile can be edited by hand. What
// belongs to a widget is written under `widgets.<id>.`, so this page is a
// second way to reach settings the Widgets page also shows rather than a
// second set of settings.

import QtQuick
import Quickshell
import qs.domain.config
import qs.domain.panel.menu
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    // Set by the settings window: opens another page by its schema id.
    property var openPage: id => {}

    readonly property bool autoHide: ConfigStore.value("panel.autoHide", false) === true

    // The right-click menu. What the monitor row can be set to is what is
    // installed -- PanelMenuModel is the one place that knows -- plus the two
    // answers that are not an application: follow what is installed, or no row.
    readonly property string monitorSetting: ConfigStore.value("panel.menu.systemMonitor", "auto")
    readonly property var monitorChoices: {
        const installed = PanelMenuModel.installedMonitors;
        const out = [{ id: "auto", label: installed.length > 0 ? `Automatic (${installed[0].name})` : "Automatic" }];
        for (const m of installed)
            out.push({ id: m.id, label: m.name });
        out.push({ id: "none", label: "Do not show the row" });
        // A monitor named in the profile that is no longer installed would
        // otherwise leave the dropdown showing the first choice while the
        // setting said something else -- so it is offered, and named as gone.
        if (out.findIndex(c => c.id === root.monitorSetting) < 0)
            out.push({ id: root.monitorSetting, label: `${root.monitorSetting} (not installed)` });
        return out;
    }

    // The raw list as written, not PanelMenuModel's normalised view: a half
    // finished entry must stay on the page to be finished, and normalising
    // would drop it the moment the name was typed and the command was not.
    readonly property var customEntries: {
        const raw = ConfigStore.value("panel.menu.entries", []);
        return Array.isArray(raw) ? raw : [];
    }

    function writeEntries(list): void {
        ConfigStore.set("panel.menu.entries", list);
    }

    function updateEntry(index, patch): void {
        const list = root.customEntries.map(e => Object.assign({}, e));
        if (index < 0 || index >= list.length)
            return;
        root.writeEntries(list.map((e, i) => i === index ? Object.assign(e, patch) : e));
    }

    function removeEntry(index): void {
        root.writeEntries(root.customEntries.filter((e, i) => i !== index));
    }

    function addEntry(): void {
        root.writeEntries(root.customEntries.concat([{ label: "", command: "", glyph: "terminal" }]));
    }

    spacing: 14

    Card {
        width: root.width

        SectionLabel { text: "Position" }

        ConfigSegmented {
            width: parent.width
            values: ["top", "bottom", "left", "right"]
            labels: ["Top", "Bottom", "Left", "Right"]
            path: "panel.position"
        }

        ConfigToggleRow {
            label: "Hide until pointed at"
            description: "The panel shrinks to a sliver and reserves no space, so windows use the whole screen."
            path: "panel.autoHide"
        }

        ConfigToggleRow {
            label: "Reveal on hover"
            description: root.autoHide ? "The panel comes back when the pointer reaches the screen edge."
                                       : "Only matters while the panel hides."
            enabled: root.autoHide
            path: "panel.revealOnHover"
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Style" }

        ConfigSegmented {
            width: parent.width
            values: ["full", "floating", "islands"]
            labels: ["Full width", "Floating bar", "Islands"]
            path: "panel.style"
        }

        Hint {
            text: "Full width is a strip along the whole edge. Floating is a rounded bar held clear of it. Islands draws no bar at all: each zone is a rounded island of its own."
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Sizing" }

        ConfigSliderRow {
            label: "Bar thickness"
            from: 28
            to: 96
            stepSize: 2
            path: "panel.thickness"
        }

        SliderRow {
            label: "Corner rounding"
            from: 0
            to: 36
            stepSize: 2
            // Theme.rounding, not the configuration key with a fallback of
            // its own: this slider carried 18 while the shipped default is 28,
            // so with the key unset it sat in the wrong place and jumped the
            // moment it was touched. The theme is the one that decides.
            value: Theme.rounding
            onMoved: value => ConfigStore.set("theme.rounding", Math.round(value))
        }

        ConfigSliderRow {
            label: "Tray icon size"
            from: 15
            to: 26
            path: "panel.iconSize"
        }

        ConfigSliderRow {
            label: "Spacing between widgets"
            from: 2
            to: 16
            path: "panel.spacing"
        }
    }

    Card {
        id: clockCard
        width: root.width

        SectionLabel { text: "Clock" }

        // A format of the person's own wins over the three choices below, so
        // while there is one they say so rather than switching nothing.
        readonly property string customFormat: ConfigStore.value("widgets.clock.format", "") ?? ""

        Segmented {
            enabled: clockCard.customFormat.length === 0
            opacity: enabled ? 1 : 0.5
            width: parent.width
            values: ["24", "12"]
            labels: ["24-hour", "12-hour"]
            current: ConfigStore.value("widgets.clock.hour12", false) === true ? "12" : "24"
            onPicked: value => ConfigStore.set("widgets.clock.hour12", value === "12")
        }

        ConfigToggleRow {
            label: "Show the date"
            description: "Under the time; beside it on a thin panel, and not at all down the side of the screen."
            path: "widgets.clock.showDate"
        }

        ConfigToggleRow {
            enabled: clockCard.customFormat.length === 0
            label: "Show seconds"
            path: "widgets.clock.showSeconds"
        }

        TextInputRow {
            width: parent.width
            placeholderText: "HH:mm"
            text: clockCard.customFormat
            onCommitted: value => ConfigStore.set("widgets.clock.format", value.trim())
        }

        Hint {
            text: clockCard.customFormat.length > 0
                ? `A format of your own, "${clockCard.customFormat}", is in use, so the choices above wait. Empty the field to use them again.`
                : "A format of your own, as Qt writes one -- \"ddd HH:mm\", say -- wins over the choices above. Empty for those."
            lineHeight: 1
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Workspaces" }

        ConfigSegmented {
            width: parent.width
            values: ["numbers", "icons", "dots"]
            labels: ["Numbers", "App icons", "Dots"]
            path: "widgets.workspaces.style"
        }

        // These two have no shipped default of their own -- the widget's
        // manifest has them -- so the fallbacks here are what is shown.
        ConfigSliderRow {
            label: "Desktops shown"
            unit: ""
            from: 1
            to: 20
            path: "widgets.workspaces.maxShown"
            fallback: 8
        }

        ConfigToggleRow {
            label: "Switch by scrolling"
            path: "widgets.workspaces.scrollToSwitch"
            fallback: true
        }

        Hint {
            text: "These are KWin's virtual desktops. Adding and naming them is System Settings' page, which Plasma and this shell both read."
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Window buttons" }

        ConfigToggleRow {
            label: "Show titles"
            description: "Off, buttons are icons alone and the title is one hover away."
            path: "widgets.tasks.showTitles"
        }

        // The rest have no shipped default of their own -- the widget's
        // manifest has them -- so the fallbacks here are what is shown.
        ConfigToggleRow {
            label: "Group windows by application"
            path: "widgets.tasks.groupByApp"
            fallback: true
        }

        ConfigToggleRow {
            label: "Only this screen's windows"
            description: "Each monitor's panel lists the windows on that monitor."
            path: "widgets.tasks.thisScreenOnly"
            fallback: false
        }

        ConfigToggleRow {
            label: "Stack the icon of an application with several windows"
            description: "A second square behind the icon, so the count shows on the button itself."
            path: "widgets.tasks.stackGroups"
            fallback: true
        }

        ConfigToggleRow {
            label: "Name the application above its previews"
            description: "Off, each window's card carries the icon and title itself, as Windows draws them."
            path: "widgets.tasks.previewHeader"
            fallback: false
        }

        ConfigToggleRow {
            label: "Name the monitor on each preview"
            description: "With more than one monitor, the one a window is on -- \"DP-2\" -- after its title."
            path: "widgets.tasks.previewScreen"
            fallback: false
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Right-click menu" }

        Hint {
            text: "The menu a right click on empty panel opens. Its first rows -- settings, widgets, reloading -- are fixed; the monitor it offers and anything below it are yours."
        }

        SettingRow {
            label: "System monitor"
            description: root.monitorChoices.length > 1
                ? "Which one the System monitor row opens. Only what is installed is offered."
                : "No system monitor is installed, so the row is left off the menu."
            controlWidth: 190
            enabled: root.monitorChoices.length > 1
            overridden: ConfigStore.isOverridden("panel.menu.systemMonitor")
            onResetRequested: ConfigStore.set("panel.menu.systemMonitor", "auto")

            Select {
                implicitWidth: 190
                values: root.monitorChoices.map(c => c.label)
                currentIndex: Math.max(0, root.monitorChoices.findIndex(c => c.id === root.monitorSetting))
                onPicked: label => {
                    const choice = root.monitorChoices.find(c => c.label === label);
                    if (choice)
                        ConfigStore.set("panel.menu.systemMonitor", choice.id);
                }
            }
        }

        SectionLabel { text: "Your own entries" }

        Hint {
            text: "Each row runs a command line, the way a terminal would -- pipes, arguments and $HOME all work. It is run detached, so a script that keeps going is not stopped when the menu closes. A row with no name or no command is not drawn."
        }

        Repeater {
            model: root.customEntries

            // One entry: what it is called, what it runs, and a way to remove
            // it. Written back on losing focus or on Enter, never per
            // keystroke -- see TextInputRow.
            Column {
                id: entryRow

                required property var modelData
                required property int index

                width: root.width - 32
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 8

                    TextInputRow {
                        id: labelField
                        width: parent.width - commandField.width - removeButton.width - parent.spacing * 2
                        text: String(entryRow.modelData.label ?? "")
                        placeholderText: "Name"
                        onCommitted: value => root.updateEntry(entryRow.index, { label: value })
                    }

                    TextInputRow {
                        id: commandField
                        width: Math.round((parent.width - removeButton.width - parent.spacing * 2) * 0.55)
                        text: String(entryRow.modelData.command ?? "")
                        placeholderText: "Command"
                        onCommitted: value => root.updateEntry(entryRow.index, { command: value })
                    }

                    IconButton {
                        id: removeButton
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "delete"
                        iconName: "edit-delete"
                        tooltip: "Remove this entry"
                        color: Theme.error
                        onActivated: root.removeEntry(entryRow.index)
                    }
                }
            }
        }

        TextButton {
            glyph: "add"
            iconName: "list-add"
            text: "Add an entry"
            onActivated: root.addEntry()
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Entries" }

        Hint {
            text: "Which widgets are on the panel, in which zone and in which order, is the Widgets page -- where a row is dragged rather than typed."
        }

        TextButton {
            glyph: "widgets"
            iconName: "configure"
            text: "Open the widgets page"
            onActivated: root.openPage("widgets")
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Displays" }

        Hint {
            text: Quickshell.screens.length > 1
                ? "Each monitor draws its own panel. Where it sits, how it is drawn, whether it hides and its size can differ per monitor; the widgets are shared."
                : "One monitor. With a second one connected, each draws its own panel and can keep its own position, style, hiding and size."
        }

        Repeater {
            model: Quickshell.screens

            Column {
                id: screenBlock

                required property var modelData

                readonly property string name: screenBlock.modelData.name
                // Every key the panel reads per screen (PanelModel.*For) that
                // this block offers. Setting one back to the shared value
                // drops the override rather than freezing a copy of it.
                readonly property var ownKeys: ["panel.position", "panel.thickness", "panel.style",
                                                 "panel.autoHide", "panel.iconSize"]
                readonly property bool overridden: screenBlock.ownKeys.some(
                    k => ConfigStore.isOverriddenForScreen(screenBlock.name, k))

                function useShared() {
                    for (const k of screenBlock.ownKeys)
                        ConfigStore.setForScreen(screenBlock.name, k, ConfigStore.value(k, undefined));
                }

                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: 24

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${screenBlock.name} · ${screenBlock.modelData.width}×${screenBlock.modelData.height}`
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    PanelText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: screenBlock.overridden
                        text: "its own"
                        font.pixelSize: 12
                        color: Theme.acc
                    }
                }

                ConfigSegmented {
                    width: parent.width
                    values: ["top", "bottom", "left", "right"]
                    labels: ["Top", "Bottom", "Left", "Right"]
                    screen: screenBlock.name
                    path: "panel.position"
                }

                ConfigSliderRow {
                    label: "Thickness on this monitor"
                    from: 28
                    to: 96
                    stepSize: 2
                    screen: screenBlock.name
                    path: "panel.thickness"
                }

                ConfigSegmented {
                    width: parent.width
                    values: ["full", "floating", "islands"]
                    labels: ["Full width", "Floating bar", "Islands"]
                    screen: screenBlock.name
                    path: "panel.style"
                }

                ConfigSliderRow {
                    label: "Tray icon size on this monitor"
                    from: 15
                    to: 26
                    screen: screenBlock.name
                    path: "panel.iconSize"
                }

                ConfigToggleRow {
                    width: parent.width
                    label: "Hide until pointed at, on this monitor"
                    screen: screenBlock.name
                    path: "panel.autoHide"
                }

                TextButton {
                    visible: screenBlock.overridden
                    glyph: "sync"
                    iconName: "edit-undo"
                    text: "Use the shared settings"
                    onActivated: screenBlock.useShared()
                }
            }
        }
    }
}
