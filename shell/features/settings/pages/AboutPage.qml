pragma ComponentBehavior: Bound

// Version, paths, and where things live.

import QtQuick
import qs.core
import qs.domain.theme
import qs.domain.launcher
import qs.domain.widgets
import qs.ui.primitives

CardGrid {
    id: root

    count: 2

    Card {
        id: what

        width: root.cellWidth
        spacing: 6

        SectionLabel { text: "This shell" }

        PanelText {
            text: `${Branding.displayName} ${Branding.version}`
            font.pixelSize: 18
            font.weight: Font.Medium
        }

        PanelText {
            width: what.width - 2 * what.padding
            wrapMode: Text.WordWrap
            text: "A configurable desktop shell for KDE Plasma."
            font.pixelSize: 13
            color: Theme.mut
        }

        PanelText {
            text: "quickshell · wayland"
            font.family: Theme.monoFamily
            font.pixelSize: 12
            color: Theme.mut
        }
    }

    Card {
        id: where

        width: root.cellWidth
        spacing: 8

        SectionLabel { text: "Where things live" }

        Repeater {
            model: [
                { label: "Configuration",  value: Branding.configDir },
                { label: "Shell",          value: Branding.qsConfigDir },
                { label: "State",          value: Branding.stateDir },
                { label: "Widgets",        value: `${Object.keys(WidgetRegistry.all).length} installed` },
                { label: "Menu opens",     value: LauncherService.appsProvider.providerId },
                { label: "Search opens",   value: LauncherService.searchProvider.providerId }
            ]

            // The label above the value rather than beside it: a path is as
            // long as it is, and a column wide enough for the longest one
            // leaves the short ones stranded.
            Column {
                id: line

                required property var modelData

                width: where.width - 2 * where.padding
                spacing: 1

                PanelText {
                    text: line.modelData.label
                    font.pixelSize: 12
                    color: Theme.mut
                }

                PanelText {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: line.modelData.value
                    font.family: Theme.monoFamily
                    font.pixelSize: 12
                }
            }
        }
    }
}
