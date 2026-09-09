// Version, paths, and where things live.

import QtQuick
import qs.core
import qs.domain.theme
import qs.domain.launcher
import qs.domain.widgets
import qs.ui.primitives

Column {
    id: root

    spacing: 4

    PanelText {
        text: `${Branding.displayName} ${Branding.version}`
        font.pixelSize: 16
    }

    PanelText {
        text: "A configurable desktop shell for KDE Plasma."
        color: PlasmaColors.foregroundInactive
        bottomPadding: 8
    }

    Repeater {
        model: [
            { label: "Configuration",  value: Branding.configDir },
            { label: "Shell",          value: Branding.qsConfigDir },
            { label: "State",          value: Branding.stateDir },
            { label: "Widgets",        value: `${Object.keys(WidgetRegistry.all).length} installed` },
            { label: "Menu opens",     value: LauncherService.appsProvider.providerId },
            { label: "Search opens",   value: LauncherService.searchProvider.providerId }
        ]

        Row {
            id: line
            required property var modelData
            spacing: 10

            PanelText {
                width: 120
                text: line.modelData.label
                color: PlasmaColors.foregroundInactive
            }

            PanelText { text: line.modelData.value }
        }
    }
}
