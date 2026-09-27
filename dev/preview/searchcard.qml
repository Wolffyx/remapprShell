import QtQuick
import Quickshell
import qs.domain.theme
import qs.domain.launcher
import qs.features.launcher

Stage {
    id: stage
    middle: false

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
