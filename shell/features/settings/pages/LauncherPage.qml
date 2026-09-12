pragma ComponentBehavior: Bound

// Launcher: which program opens on the menu key and on the search key, and
// how this shell's own menu looks when it is the one that opens.
//
// Plasma's Kickoff and KRunner are the default, and stay the default: the
// built-in menu is offered, not imposed. The layout settings below only apply
// while the built-in one is in use, and say so.

import QtQuick
import qs.domain.config
import qs.domain.launcher
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    readonly property bool builtinMenu: LauncherService.appsProvider?.providerId === "builtin"
    readonly property bool builtinSearch: LauncherService.searchProvider?.providerId === "builtin"

    spacing: 14

    Card {
        width: root.width

        SectionLabel { text: "What opens" }

        SettingRow {
            width: parent.width
            label: "Application menu"
            description: `Now: ${LauncherService.appsProvider?.label ?? "none"}.`

            Select {
                values: ["auto"].concat(LauncherService.availableProviders.map(p => p.providerId))
                currentIndex: Math.max(0, ["auto"].concat(LauncherService.availableProviders.map(p => p.providerId))
                                              .indexOf(ConfigStore.value("launcher.provider", "auto")))
                onPicked: value => ConfigStore.set("launcher.provider", value)
            }
        }

        SettingRow {
            width: parent.width
            label: "Search"
            description: `Now: ${LauncherService.searchProvider?.label ?? "none"}.`

            Select {
                values: ["auto"].concat(LauncherService.availableProviders.map(p => p.providerId))
                currentIndex: Math.max(0, ["auto"].concat(LauncherService.availableProviders.map(p => p.providerId))
                                              .indexOf(ConfigStore.value("launcher.searchProvider", "auto")))
                onPicked: value => ConfigStore.set("launcher.searchProvider", value)
            }
        }
    }

    Card {
        width: root.width
        opacity: root.builtinMenu ? 1 : 0.6

        SectionLabel { text: "Start menu layout" }

        Segmented {
            width: parent.width
            values: ["twopane", "grid", "list"]
            labels: ["Two-pane", "Pinned grid", "A–Z list"]
            glyphs: ["vertical_split", "grid_view", "sort_by_alpha"]
            current: ConfigStore.value("launcher.layout", "twopane")
            onPicked: value => ConfigStore.set("launcher.layout", value)
        }

        PanelText {
            width: parent.width
            visible: !root.builtinMenu
            wrapMode: Text.WordWrap
            text: "The menu key opens Plasma's Kickoff at the moment, which has a layout of its own."
            font.pixelSize: 12
            color: Theme.mut
        }
    }

    Card {
        width: root.width
        opacity: root.builtinSearch ? 1 : 0.6

        SectionLabel { text: "Search" }

        ToggleRow {
            label: "Compact rows"
            description: "More results in the same room."
            checked: ConfigStore.value("launcher.dense", false) === true
            onToggled: value => ConfigStore.set("launcher.dense", value)
        }

        ToggleRow {
            label: "Key hints along the bottom"
            checked: ConfigStore.value("launcher.hints", true) === true
            onToggled: value => ConfigStore.set("launcher.hints", value)
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Action prefix" }

        Segmented {
            width: parent.width
            values: [">", ":", "/"]
            current: ConfigStore.value("launcher.actionPrefix", ">")
            onPicked: value => ConfigStore.set("launcher.actionPrefix", value)
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Typed at the start of a search, this runs the shell's own actions -- lock, log out, the sidebar, the key sheet -- instead of looking for applications."
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
        }

        Row {
            spacing: 8

            TextButton {
                glyph: "apps"
                iconName: "start-here-kde"
                text: "Open the menu"
                onActivated: LauncherService.open("apps")
            }

            TextButton {
                glyph: "search"
                iconName: "system-search"
                text: "Open search"
                onActivated: LauncherService.open("search")
            }
        }
    }
}
