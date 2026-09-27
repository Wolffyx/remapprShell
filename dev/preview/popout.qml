import QtQuick
import Quickshell
import qs.domain.theme
import qs.domain.config
import qs.domain.notifications

Stage {
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

    readonly property string wid: Quickshell.env("PREVIEW_WIDGET") || "status"
    readonly property string page: Quickshell.env("PREVIEW_PAGE") || ""
    readonly property string cfg: Quickshell.env("PREVIEW_CONFIG") || "{}"
    readonly property int padding: parseInt(Quickshell.env("PREVIEW_PADDING") || "20")

    MockBar { id: mock }

    Loader {
        id: w
        visible: false
        Component.onCompleted: w.setSource(Qt.resolvedUrl(`widgets/${stage.wid}/Widget.qml`),
                                           { bar: mock, widgetConfig: JSON.parse(stage.cfg), screenName: "PREVIEW" })
        onLoaded: {
            if (stage.page.length > 0)
                w.item.page = stage.page;
            w.item.popoutVisible = true;
            // A widget whose popout has two contents -- the taskbar's preview
            // and its right-click menu -- needs saying which. PREVIEW_MENU
            // picks the menu, on the first button there is.
            if (Quickshell.env("PREVIEW_MENU")) {
                menuTimer.start();
            }
            // The taskbar's hover card is about a button, and which one is
            // normally answered by the pointer. PREVIEW_GROUP picks the first
            // button with more than one window, which is the case the card
            // exists for.
            if (Quickshell.env("PREVIEW_GROUP")) {
                groupTimer.start();
            }
        }
    }

    // The button list is filled from the window daemon, which answers a moment
    // after this loads.
    Timer {
        id: menuTimer
        interval: 400
        repeat: false
        onTriggered: {
            const items = w.item?.items ?? [];
            if (items.length === 0) {
                console.warn("preview: no taskbar buttons to open a menu on");
                return;
            }
            w.item.openMenu(items[0]);
        }
    }

    Timer {
        id: groupTimer
        interval: 400
        repeat: false
        onTriggered: {
            const items = w.item?.items ?? [];
            const group = items.find(i => i.windows.length > 1) ?? items[0] ?? null;
            if (!group) {
                console.warn("preview: no taskbar button to preview");
                return;
            }
            w.item.previewItem = group;
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
