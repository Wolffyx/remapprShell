import QtQuick
import Quickshell
import qs.domain.theme
import qs.domain.config
import qs.domain.notifications

Rectangle {
    id: stage

    // Sample notifications, for the centre -- the eavesdrop starts empty.
    Component.onCompleted: {
        const runtime = JSON.parse(Quickshell.env("PREVIEW_RUNTIME") || "{}");
        for (const k of Object.keys(runtime))
            ConfigStore.setRuntime(k, runtime[k]);
        if (Quickshell.env("PREVIEW_STYLE"))
            ConfigStore.setRuntime("notifications.centreStyle", Quickshell.env("PREVIEW_STYLE"));
        if (Quickshell.env("PREVIEW_NOTES")) {
            ConfigStore.setRuntime("notifications.history", true);
            const t = Date.now();
            const n = (app, icon, s, b, min) => ({ appName: app, appIcon: icon, summary: s, body: b, urgency: 1, when: t - min * 60000 });
            NotificationWatch.entries = [
                n("Messages", "", "Kai sent a message", "Pushed the patch for the tray popouts, take a look when you get a sec", 2),
                n("Messages", "", "Nadia mentioned you", "#rice-discussion · screenshot of the new bar?", 25),
                n("System", "", "42 packages can be updated", "Includes linux-zen 6.16.4 and mesa 25.2", 46),
                n("Messages", "", "Kai sent a photo", "", 70),
                n("Power", "", "Charger disconnected", "Profile switched to balanced", 60 * 20),
                n("Spectacle", "", "Screenshot saved", "~/Pictures/Screenshots/2026-09-11.png", 60 * 50)
            ];
        }
    }
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.dark ? "#20283f" : "#c8d5ef" }
        GradientStop { position: 0.45; color: Theme.dark ? "#2c2b3d" : "#e6dcd2" }
        GradientStop { position: 1; color: Theme.dark ? "#3b3138" : "#f2d7c4" }
    }

    readonly property string wid: Quickshell.env("PREVIEW_WIDGET") || "status"
    readonly property string page: Quickshell.env("PREVIEW_PAGE") || ""
    readonly property string cfg: Quickshell.env("PREVIEW_CONFIG") || "{}"
    readonly property int padding: parseInt(Quickshell.env("PREVIEW_PADDING") || "20")

    QtObject {
        id: mock
        property string screenName: "PREVIEW"
        property string position: "bottom"
        property bool horizontal: true
        property int thickness: 64
        property var screenObject: null
        property string style: "full"
        property int spacing: 6
        property int iconSize: 19
        property int edgeGap: 0
        property int extent: 64
        property Item openPopout: null
    }

    Loader {
        id: w
        visible: false
        Component.onCompleted: w.setSource(Qt.resolvedUrl(`widgets/${stage.wid}/Widget.qml`),
                                           { bar: mock, widgetConfig: JSON.parse(stage.cfg), screenName: "PREVIEW" })
        onLoaded: {
            if (stage.page.length > 0)
                w.item.page = stage.page;
            w.item.popoutVisible = true;
        }
    }

    Rectangle {
        x: 40
        y: 40
        width: content.implicitWidth + 2 * stage.padding
        height: content.implicitHeight + 2 * stage.padding
        radius: Math.min(Theme.radius, width / 2, height / 2)
        color: Theme.glass
        border.width: 1
        border.color: Theme.out

        Loader {
            id: content
            x: stage.padding
            y: stage.padding
            sourceComponent: w.item ? w.item.popout : null
        }
    }
}
