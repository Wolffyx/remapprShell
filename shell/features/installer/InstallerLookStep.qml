// The rest: the look and feel, the window previews, starting at login, and
// -- folded away, for development -- whether the files are copied or linked.

import QtQuick
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    required property var answers
    property bool needsBuildTools: false
    signal answered(string key, var value)

    spacing: 12

    Card {
        width: parent.width

        ToggleRow {
            label: "Apply the look and feel"
            description: "Colours, icons, the splash screen and Alt+Tab's look, light and dark. Plasma's are put back if you uninstall."
            checked: root.answers.theme
            onToggled: value => root.answered("theme", value)
        }

        ToggleRow {
            label: "Build the window previews"
            description: root.needsBuildTools
                ? "Live pictures of each window on the taskbar and in Alt+Tab. A compiler and Qt's development files are installed for it, which asks for your password."
                : "Live pictures of each window on the taskbar and in Alt+Tab."
            checked: root.answers.previews
            onToggled: value => root.answered("previews", value)
        }

        ToggleRow {
            label: "Start at login"
            description: "Off, the shell runs now and not after you next log in."
            checked: root.answers.autostart
            onToggled: value => root.answered("autostart", value)
        }
    }

    Fold {
        id: advanced
        label: "Advanced"
    }

    Card {
        visible: advanced.open
        width: parent.width

        SectionLabel { text: "Install as" }

        Segmented {
            width: parent.width
            values: ["copy", "link"]
            labels: ["A copy of the files", "Links to this source (development)"]
            current: root.answers.mode
            onPicked: value => root.answered("mode", value)
        }

        Hint {
            text: "Linked, every edit to the source is live at once. For working on the shell, not for using it."
        }
    }
}
