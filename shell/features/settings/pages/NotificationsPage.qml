pragma ComponentBehavior: Bound

// Notifications: who draws them, where they appear and what is remembered.
//
// Plasma draws them by default, and under this shell's own renderer that
// means the Plasma applet this shell hosts. Asking the shell to draw them is
// one setting, and it never takes the name from another program -- see the
// notes beside "Drawn by".

import QtQuick
import Quickshell
import qs.domain.config
import qs.domain.notifications
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    readonly property string server: ConfigStore.value("notifications.server", "shell")

    spacing: 14

    Card {
        width: root.width

        SectionLabel { text: "Drawn by" }

        ConfigSegmented {
            width: parent.width
            values: ["plasma", "shell"]
            labels: ["Plasma", "This shell"]
            path: "notifications.server"
        }

        Hint {
            text: root.server === "shell"
                ? (ShellNotifications.active
                    ? "The shell holds org.freedesktop.Notifications and draws the popups below."
                    : `Not drawing them${ShellNotifications.reason ? ": " + ShellNotifications.reason : " yet"}. Nothing is taken from whoever holds the name; the shell waits for it to be let go of.`)
                : "Plasma's own notifications, through the applet this shell hosts outside the panel. Its history and do-not-disturb are in that applet."
        }
    }

    Card {
        width: root.width
        opacity: root.server === "shell" ? 1 : 0.6

        SectionLabel { text: "Popups" }

        ConfigSegmented {
            width: parent.width
            equal: false
            minimumWidth: 120
            values: ["auto", "top-right", "top-center", "top-left", "bottom-right", "bottom-center", "bottom-left"]
            labels: ["Beside the clock", "Top right", "Top centre", "Top left", "Bottom right", "Bottom centre", "Bottom left"]
            path: "notifications.popupPosition"
        }

        ConfigSliderRow {
            label: "Dismiss after"
            unit: "s"
            from: 2
            to: 20
            path: "notifications.popupTimeout"
        }

        Hint {
            text: "An application that asks for a particular time gets it; an urgent notification stays until it is answered."
        }

        TextButton {
            glyph: "notifications_active"
            iconName: "dialog-information"
            text: "Send a test notification"
            onActivated: Quickshell.execDetached(["notify-send", "-a", "Settings",
                                                  "-i", "preferences-desktop-notification",
                                                  "A test notification",
                                                  "This is what one looks like where they are now set to appear."])
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "The centre" }

        ConfigSegmented {
            width: parent.width
            values: ["grouped", "stream"]
            labels: ["Grouped by application", "One long stream"]
            path: "notifications.centreStyle"
        }

        ConfigToggleRow {
            label: "Remember what went past"
            description: "In memory only, never written to disk. The bell widget reads it, and so does `rmpr ask --last-notification`."
            path: "notifications.history"
        }

        ConfigSliderRow {
            label: "Remembered at most"
            unit: ""
            from: 10
            to: 300
            stepSize: 10
            path: "notifications.historySize"
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Interruptions" }

        ToggleRow {
            label: "Do not disturb"
            description: DoNotDisturb.shellDraws
                ? "Silences everything but an urgent notification while the shell draws them."
                : "Written to Plasma's own do-not-disturb, so Plasma's notifications honour it too."
            checked: DoNotDisturb.active
            onToggled: value => DoNotDisturb.set(value)
        }
    }
}
