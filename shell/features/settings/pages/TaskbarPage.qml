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
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    // Set by the settings window: opens another page by its schema id.
    property var openPage: id => {}

    readonly property string position: ConfigStore.value("panel.position", "bottom")
    readonly property bool autoHide: ConfigStore.value("panel.autoHide", false) === true

    spacing: 14

    Card {
        width: root.width

        SectionLabel { text: "Position" }

        Segmented {
            width: parent.width
            values: ["top", "bottom", "left", "right"]
            labels: ["Top", "Bottom", "Left", "Right"]
            current: root.position
            onPicked: value => ConfigStore.set("panel.position", value)
        }

        ToggleRow {
            label: "Hide until pointed at"
            description: "The panel shrinks to a sliver and reserves no space, so windows use the whole screen."
            checked: root.autoHide
            onToggled: value => ConfigStore.set("panel.autoHide", value)
        }

        ToggleRow {
            label: "Reveal on hover"
            description: root.autoHide ? "The panel comes back when the pointer reaches the screen edge."
                                       : "Only matters while the panel hides."
            enabled: root.autoHide
            checked: ConfigStore.value("panel.revealOnHover", true) === true
            onToggled: value => ConfigStore.set("panel.revealOnHover", value)
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Style" }

        Segmented {
            width: parent.width
            values: ["full", "floating", "islands"]
            labels: ["Full width", "Floating bar", "Islands"]
            current: ConfigStore.value("panel.style", "full")
            onPicked: value => ConfigStore.set("panel.style", value)
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Full width is a strip along the whole edge. Floating is a rounded bar held clear of it. Islands draws no bar at all: each zone is a rounded island of its own."
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Sizing" }

        SliderRow {
            label: "Bar thickness"
            from: 28
            to: 96
            stepSize: 2
            value: ConfigStore.value("panel.thickness", 56)
            onMoved: value => ConfigStore.set("panel.thickness", Math.round(value))
        }

        SliderRow {
            label: "Corner rounding"
            from: 0
            to: 36
            stepSize: 2
            value: ConfigStore.value("theme.rounding", 18)
            onMoved: value => ConfigStore.set("theme.rounding", Math.round(value))
        }

        SliderRow {
            label: "Tray icon size"
            from: 15
            to: 26
            value: ConfigStore.value("panel.iconSize", 19)
            onMoved: value => ConfigStore.set("panel.iconSize", Math.round(value))
        }

        SliderRow {
            label: "Spacing between widgets"
            from: 2
            to: 16
            value: ConfigStore.value("panel.spacing", 6)
            onMoved: value => ConfigStore.set("panel.spacing", Math.round(value))
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Clock" }

        Segmented {
            width: parent.width
            values: ["24", "12"]
            labels: ["24-hour", "12-hour"]
            current: ConfigStore.value("widgets.clock.hour12", false) === true ? "12" : "24"
            onPicked: value => ConfigStore.set("widgets.clock.hour12", value === "12")
        }

        ToggleRow {
            label: "Show the date"
            description: "Under the time; beside it on a thin panel, and not at all down the side of the screen."
            checked: ConfigStore.value("widgets.clock.showDate", true) === true
            onToggled: value => ConfigStore.set("widgets.clock.showDate", value)
        }

        ToggleRow {
            label: "Show seconds"
            checked: ConfigStore.value("widgets.clock.showSeconds", false) === true
            onToggled: value => ConfigStore.set("widgets.clock.showSeconds", value)
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Workspaces" }

        Segmented {
            width: parent.width
            values: ["numbers", "icons", "dots"]
            labels: ["Numbers", "App icons", "Dots"]
            current: ConfigStore.value("widgets.workspaces.style", "numbers")
            onPicked: value => ConfigStore.set("widgets.workspaces.style", value)
        }

        SliderRow {
            label: "Desktops shown"
            unit: ""
            from: 1
            to: 20
            value: ConfigStore.value("widgets.workspaces.maxShown", 8)
            onMoved: value => ConfigStore.set("widgets.workspaces.maxShown", Math.round(value))
        }

        ToggleRow {
            label: "Switch by scrolling"
            checked: ConfigStore.value("widgets.workspaces.scrollToSwitch", true) === true
            onToggled: value => ConfigStore.set("widgets.workspaces.scrollToSwitch", value)
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "These are KWin's virtual desktops. Adding and naming them is System Settings' page, which Plasma and this shell both read."
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Window buttons" }

        ToggleRow {
            label: "Show titles"
            description: "Off, buttons are icons alone and the title is one hover away."
            checked: ConfigStore.value("widgets.tasks.showTitles", true) === true
            onToggled: value => ConfigStore.set("widgets.tasks.showTitles", value)
        }

        ToggleRow {
            label: "Group windows by application"
            checked: ConfigStore.value("widgets.tasks.groupByApp", true) === true
            onToggled: value => ConfigStore.set("widgets.tasks.groupByApp", value)
        }

        ToggleRow {
            label: "Only this screen's windows"
            description: "Each monitor's panel lists the windows on that monitor."
            checked: ConfigStore.value("widgets.tasks.thisScreenOnly", false) === true
            onToggled: value => ConfigStore.set("widgets.tasks.thisScreenOnly", value)
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Entries" }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Which widgets are on the panel, in which zone and in which order, is the Widgets page -- where a row is dragged rather than typed."
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
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

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: Quickshell.screens.length > 1
                ? "Each monitor draws its own panel. Position and thickness can differ per monitor; everything else is shared."
                : "One monitor. With a second one connected, each draws its own panel and can keep its own position and thickness."
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
        }

        Repeater {
            model: Quickshell.screens

            Column {
                id: screenBlock

                required property var modelData

                readonly property string name: screenBlock.modelData.name
                readonly property bool overridden: ConfigStore.isOverriddenForScreen(screenBlock.name, "panel.position")
                            || ConfigStore.isOverriddenForScreen(screenBlock.name, "panel.thickness")

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

                Segmented {
                    width: parent.width
                    values: ["top", "bottom", "left", "right"]
                    labels: ["Top", "Bottom", "Left", "Right"]
                    current: ConfigStore.valueFor(screenBlock.name, "panel.position", "bottom")
                    onPicked: value => ConfigStore.setForScreen(screenBlock.name, "panel.position", value)
                }

                SliderRow {
                    label: "Thickness on this monitor"
                    from: 28
                    to: 96
                    stepSize: 2
                    value: ConfigStore.valueFor(screenBlock.name, "panel.thickness", 56)
                    onMoved: value => ConfigStore.setForScreen(screenBlock.name, "panel.thickness", Math.round(value))
                }
            }
        }
    }
}
