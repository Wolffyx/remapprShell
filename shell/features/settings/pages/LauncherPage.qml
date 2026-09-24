pragma ComponentBehavior: Bound

// Launcher: which program opens on the menu key and on the search key, and
// how this shell's own menu looks when it is the one that opens.
//
// Plasma's Kickoff and KRunner are the default, and stay the default: the
// built-in menu is offered, not imposed. The layout settings below only apply
// while the built-in one is in use, and say so.

import QtQuick
import qs.domain.config
import qs.domain.settings.groups
import qs.domain.launcher
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    readonly property bool builtinMenu: LauncherService.appsProvider?.providerId === "builtin"
    readonly property bool builtinSearch: LauncherService.searchProvider?.providerId === "builtin"

    readonly property var sources: ConfigStore.value("launcher.searchSources",
                                                     ["apps", "windows", "files", "settings"]) ?? []

    // Written back in the order the switches are drawn, not the order they
    // were turned on: the file is read by people as well as by the shell.
    function setSource(id, on) {
        const all = ["apps", "windows", "files", "settings"];
        const chosen = root.sources.slice().filter(s => s !== id);
        if (on)
            chosen.push(id);
        ConfigStore.set("launcher.searchSources", all.filter(s => chosen.indexOf(s) >= 0));
    }

    spacing: 14

    // The choices in both lists: automatic, then whatever is usable here,
    // named as the providers name themselves. A custom command is only usable
    // once there is one, which is what the field below this card is for.
    readonly property var providerIds: ["auto"].concat(LauncherService.availableProviders.map(p => p.providerId))
    readonly property var providerLabels: ["Automatic"].concat(LauncherService.availableProviders.map(p => p.label))
    readonly property bool kickoffInUse: LauncherService.appsProvider?.providerId === "kickoff"
                                         || LauncherService.searchProvider?.providerId === "kickoff"

    Card {
        width: root.width

        SectionLabel { text: "What opens" }

        SettingRow {
            width: parent.width
            label: "Application menu"
            description: `Now: ${LauncherService.appsProvider?.label ?? "none"}.`

            Select {
                values: root.providerIds
                labels: root.providerLabels
                currentIndex: Math.max(0, root.providerIds.indexOf(ConfigStore.value("launcher.provider", "builtin")))
                onPicked: value => ConfigStore.set("launcher.provider", value)
            }
        }

        SettingRow {
            width: parent.width
            label: "Search"
            description: `Now: ${LauncherService.searchProvider?.label ?? "none"}.`

            Select {
                values: root.providerIds
                labels: root.providerLabels
                currentIndex: Math.max(0, root.providerIds.indexOf(ConfigStore.value("launcher.searchProvider", "builtin")))
                onPicked: value => ConfigStore.set("launcher.searchProvider", value)
            }
        }

        SettingRow {
            width: parent.width
            stacked: true
            label: "A command of your own"
            description: "Any launcher, run as written -- `wofi --show drun`, say. Once it is set, \"Custom command\" is in both lists above."

            TextInputRow {
                width: parent.width
                placeholderText: "wofi --show drun"
                text: SettingGroups.formatList(ConfigStore.value("launcher.command", []) ?? [], "words")
                onCommitted: value => ConfigStore.set("launcher.command", SettingGroups.parseList(value, "words"))
            }
        }

        // Only worth asking while Kickoff is the one that opens.
        SettingRow {
            width: parent.width
            visible: root.kickoffInUse
            label: "Kickoff opens as"
            description: "A window is slower, and does not close itself when it loses focus."

            Select {
                values: ["menu", "windowed"]
                labels: ["A menu", "A window"]
                currentIndex: ConfigStore.value("launcher.kickoffMode", "menu") === "windowed" ? 1 : 0
                onPicked: value => ConfigStore.set("launcher.kickoffMode", value)
            }
        }
    }

    Card {
        width: root.width
        opacity: root.builtinMenu ? 1 : 0.6

        SectionLabel { text: "Start menu layout" }

        ConfigSegmented {
            width: parent.width
            values: ["twopane", "grid", "list"]
            labels: ["Two-pane", "Pinned grid", "A–Z list"]
            glyphs: ["vertical_split", "grid_view", "sort_by_alpha"]
            path: "launcher.layout"
        }

        Hint {
            visible: !root.builtinMenu
            text: "The menu key opens Plasma's Kickoff at the moment, which has a layout of its own."
            lineHeight: 1
        }
    }

    Card {
        width: root.width
        opacity: root.builtinSearch ? 1 : 0.6

        SectionLabel { text: "Search" }

        ConfigToggleRow {
            label: "Compact rows"
            description: "More results in the same room."
            path: "launcher.dense"
        }

        ConfigToggleRow {
            label: "Key hints along the bottom"
            path: "launcher.hints"
        }
    }

    Card {
        width: root.width
        opacity: root.builtinSearch ? 1 : 0.6

        SectionLabel { text: "What search looks through" }

        // One switch per source, written back as the list the shell reads.
        // A list rather than a key each: the order results appear in is the
        // shell's, and what a person wants to say here is "not my files".
        Repeater {
            model: [
                { id: "apps", label: "Applications", description: "Everything installed, by name, by the binary, or by its initials." },
                { id: "windows", label: "Open windows", description: "By their titles, so a window can be raised by the page it is showing." },
                { id: "files", label: "Recent files", description: "What KDE and GTK applications record having opened." },
                { id: "settings", label: "This shell's settings", description: "The pages of this window, by name." }
            ]

            ToggleRow {
                required property var modelData

                label: modelData.label
                description: modelData.description
                checked: root.sources.indexOf(modelData.id) >= 0
                onToggled: value => root.setSource(modelData.id, value)
            }
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "What it remembers" }

        ConfigToggleRow {
            label: "Learn what you open"
            description: "What has been opened before is offered first, and an empty search suggests it. Kept on this machine and sent nowhere."
            path: "launcher.learn"
        }

        Hint {
            text: `${Object.keys(Frecency.entries).length} thing(s) remembered.`
            lineHeight: 1
        }

        TextButton {
            glyph: "delete_history"
            iconName: "edit-clear-history"
            text: "Forget what I have opened"
            onActivated: Frecency.forget()
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Action prefix" }

        ConfigSegmented {
            width: parent.width
            values: [">", ":", "/"]
            path: "launcher.actionPrefix"
        }

        Hint {
            text: "Typed at the start of a search, this runs the shell's own actions -- lock, log out, the sidebar, the key sheet -- instead of looking for applications."
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
