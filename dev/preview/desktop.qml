import QtQuick
import Quickshell
import qs.domain.config
import qs.domain.theme
import qs.features.desktop

// The desktop's own two, over a stand-in wallpaper.
Rectangle {
    id: stage

    Component.onCompleted: {
        ConfigStore.setRuntime("desktop.border", true);
        ConfigStore.setRuntime("desktop.clock", true);
        const runtime = JSON.parse(Quickshell.env("PREVIEW_RUNTIME") || "{}");
        for (const k of Object.keys(runtime))
            ConfigStore.setRuntime(k, runtime[k]);
    }

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.dark ? "#20283f" : "#cfd9ef" }
        GradientStop { position: 0.5; color: Theme.dark ? "#2c2b3d" : "#e7dcd1" }
        GradientStop { position: 1; color: Theme.dark ? "#3b3138" : "#f2d8c6" }
    }

    DesktopClock { anchors.fill: parent }
    ScreenBorder { anchors.fill: parent }
}
