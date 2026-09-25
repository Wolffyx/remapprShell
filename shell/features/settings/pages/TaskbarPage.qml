pragma ComponentBehavior: Bound

// Taskbar: the panel itself, and the widgets that are really parts of it --
// the clock, the workspace pills, the window buttons.
//
// Every control here writes one configuration key, the same keys the
// reference documents and the same ones a profile can be edited by hand. What
// belongs to a widget is written under `widgets.<id>.`, so this page is a
// second way to reach settings the Widgets page also shows rather than a
// second set of settings.
//
// The two cards with state of their own -- the right-click menu, and each
// monitor's own settings -- are files of their own beside this one, named
// after the page.

import QtQuick
import qs.domain.config
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    // Set by the settings window: opens another page by its schema id.
    property var openPage: id => {}

    readonly property bool autoHide: ConfigStore.value("panel.autoHide", false) === true
    readonly property bool floats: ConfigStore.value("panel.style", "full") !== "full"

    // The choices the shared rows and each monitor's rows both offer.
    readonly property var positionValues: ["top", "bottom", "left", "right"]
    readonly property var positionLabels: ["Top", "Bottom", "Left", "Right"]
    readonly property var styleValues: ["full", "floating", "islands"]
    readonly property var styleLabels: ["Full width", "Floating bar", "Islands"]

    spacing: 14

    Card {
        width: root.width

        SectionLabel { text: "Position" }

        ConfigSegmented {
            width: parent.width
            values: root.positionValues
            labels: root.positionLabels
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

        SectionLabel { text: "Over a full-screen window" }

        ConfigSegmented {
            width: parent.width
            values: ["hide", "kwin"]
            labels: ["Step aside", "KWin's stacking"]
            fallback: "hide"
            path: "panel.fullScreen"
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Style" }

        ConfigSegmented {
            width: parent.width
            values: root.styleValues
            labels: root.styleLabels
            path: "panel.style"
        }

        Hint {
            text: "Full width is a strip along the whole edge. Floating is a rounded bar held clear of it. Islands draws no bar at all: each zone is a rounded island of its own."
        }

        ConfigToggleRow {
            label: "Fill the edge when a window reaches it"
            description: root.floats ? "A full-width strip while a window touches the panel's space -- a maximised one always does -- and floating again when none does."
                                     : "Only matters for the floating bar and islands."
            enabled: root.floats
            fallback: true
            path: "panel.defloat"
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

    TaskbarMenuCard {
        width: root.width
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

    TaskbarDisplaysCard {
        width: root.width
        positionValues: root.positionValues
        positionLabels: root.positionLabels
        styleValues: root.styleValues
        styleLabels: root.styleLabels
    }
}
