import QtQuick
import Quickshell
import qs.domain.config
import qs.domain.theme
import qs.features.settings

// PREVIEW_PAGE: a schema section id (appearance, taskbar, windows, launcher,
// notifications, lock, ...).
Rectangle {
    id: stage

    readonly property string page: Quickshell.env("PREVIEW_PAGE") || "taskbar"

    color: Theme.s1

    SettingsWindow {
        anchors.fill: parent
        sections: Schema.sections
        currentIndex: Math.max(0, Schema.sections.findIndex(s => s.id === stage.page))
    }
}
