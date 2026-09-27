pragma ComponentBehavior: Bound

// The panel: what draws it, what lists the windows on it, and who switches
// windows with Alt+Tab. setup.sh's --renderer, --window-list and --alttab.

import QtQuick
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    required property var answers
    signal answered(string key, var value)

    spacing: 12

    SectionLabel { text: "What draws the panel" }

    Repeater {
        model: [
            { id: "quickshell", title: "This shell",
              detail: "The panel, its menus and popups are this shell's. Plasma's own panel is hidden, and comes back if you uninstall." },
            { id: "plasma", title: "Plasma, in this shell's layout",
              detail: "plasmashell keeps drawing the panel, set out the way this shell would. For when you would rather Plasma's own widgets stayed." },
            { id: "none", title: "Leave it as it is",
              detail: "Whatever draws the panel now carries on. You can switch later in Settings." }
        ]
        ChoiceCard {
            id: panelChoice
            required property var modelData
            title: panelChoice.modelData.title
            detail: panelChoice.modelData.detail
            selected: root.answers.renderer === panelChoice.modelData.id
            onChosen: root.answered("renderer", panelChoice.modelData.id)
        }
    }

    Card {
        width: parent.width
        ToggleRow {
            label: "List the open windows on the taskbar"
            description: "A small KWin script tells the shell which windows are open. Without it the taskbar has no windows on it."
            checked: root.answers.windowList
            onToggled: value => root.answered("windowList", value)
        }
    }

    SectionLabel { text: "Alt+Tab" }

    Repeater {
        model: [
            { id: "plasma", title: "KWin switches, in this shell's layout",
              detail: "KWin's own switcher, drawn to match. The dependable choice: a held key is KWin's to watch, not a shell's." },
            { id: "shell", title: "This shell's own switcher",
              detail: "The shell takes Alt+Tab and draws its switcher itself." },
            { id: "none", title: "Leave Alt+Tab alone",
              detail: "Whatever Alt+Tab does now, it keeps doing." }
        ]
        ChoiceCard {
            id: tabChoice
            required property var modelData
            title: tabChoice.modelData.title
            detail: tabChoice.modelData.detail
            selected: root.answers.alttab === tabChoice.modelData.id
            onChosen: root.answered("alttab", tabChoice.modelData.id)
        }
    }
}
