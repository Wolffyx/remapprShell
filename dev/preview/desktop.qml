import QtQuick
import Quickshell
import qs.domain.config
import qs.features.desktop

// The desktop's own two, over a stand-in wallpaper.
Stage {
    id: stage
    middleAt: 0.5
    startLight: "#cfd9ef"
    middleLight: "#e7dcd1"
    endLight: "#f2d8c6"

    Component.onCompleted: {
        ConfigStore.setRuntime("desktop.border", true);
        ConfigStore.setRuntime("desktop.clock", true);
        const runtime = JSON.parse(Quickshell.env("PREVIEW_RUNTIME") || "{}");
        for (const k of Object.keys(runtime))
            ConfigStore.setRuntime(k, runtime[k]);
    }

    DesktopClock { anchors.fill: parent }
    ScreenBorder { anchors.fill: parent }
}
