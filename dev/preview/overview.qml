// The desktop overview, over a wallpaper, with desktops and windows of its
// own: this machine has one desktop, and a strip of one says nothing about
// how the strip looks.
import QtQuick
import Quickshell
import qs.domain.config
import qs.domain.theme
import qs.domain.desktops
import qs.domain.windows
import qs.domain.surfaces
import qs.features.switchers

Rectangle {
    id: stage

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.dark ? "#20283f" : "#c8d5ef" }
        GradientStop { position: 0.45; color: Theme.dark ? "#2c2b3d" : "#e6dcd2" }
        GradientStop { position: 1; color: Theme.dark ? "#3b3138" : "#f2d7c4" }
    }

    // KWin answers over the session bus a moment after this loads and
    // overwrites the stand-ins with this machine's one desktop, so they go
    // back in until the picture has been taken.
    Timer {
        interval: 200
        repeat: true
        running: true
        onTriggered: stage.fake()
    }

    Component.onCompleted: stage.fake()

    function fake() {
        // PREVIEW_RUNTIME, as the popout target takes it: the settings this
        // surface reads are worth seeing off as well as on.
        const runtime = JSON.parse(Quickshell.env("PREVIEW_RUNTIME") || "{}");
        for (const k of Object.keys(runtime))
            ConfigStore.setRuntime(k, runtime[k]);

        const w = (appId, title, desktop, stacking, minimized) => ({
            uuid: `${appId}-${stacking}`, title: title, appId: appId, desktopFile: appId,
            minimized: minimized === true, active: stacking === 9, output: "DP-2",
            stacking: stacking, desktops: [desktop]
        });
        Desktops.desktops = [
            { position: 0, id: "d1", name: "Code" },
            { position: 1, id: "d2", name: "Web" },
            { position: 2, id: "d3", name: "Media" },
            { position: 3, id: "d4", name: "Scratch" }
        ];
        Desktops.currentId = "d1";
        WindowsService.windows = [
            w("org.kde.konsole", "~ : fish — Konsole", "d1", 9),
            w("code", "shell.qml — Code", "d1", 8),
            w("org.kde.dolphin", "Projects — Dolphin", "d2", 7),
            w("firefox", "Quickshell documentation — Firefox", "d2", 6),
            w("org.kde.elisa", "Kiasmos — Blurred", "d3", 5, true)
        ];
        Surfaces.overviewDelta = 1;
    }

    Overview {
        anchors.fill: parent
        modelData: null
    }
}
