import QtQuick
import Quickshell
import qs.domain.theme
import qs.domain.launcher
import qs.features.launcher

Rectangle {
    id: stage
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.dark ? "#20283f" : "#c8d5ef" }
        GradientStop { position: 1; color: Theme.dark ? "#3b3138" : "#f2d7c4" }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Theme.dark ? 0.42 : 0.26)
    }

    Component.onCompleted: {
        LauncherService.builtin.mode = "search";
        LauncherService.builtin.query = Quickshell.env("PREVIEW_QUERY") || "";
    }

    SearchCard {
        provider: LauncherService.builtin
        width: 760
        x: 40
        y: 40
    }
}
