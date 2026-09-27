import QtQuick
import Quickshell
import qs.domain.config
import qs.domain.notifications
import qs.domain.osd
import qs.domain.surfaces
import qs.features.overlays
import qs.features.osd
import qs.features.notifications

// PREVIEW_OVERLAY: sidebar | keys | session | osd | osd-text
Stage {
    id: stage

    readonly property string which: Quickshell.env("PREVIEW_OVERLAY") || "sidebar"

    Component.onCompleted: {
        ConfigStore.setRuntime("notifications.history", true);
        const t = Date.now();
        const n = (app, s, b, min) => ({ appName: app, appIcon: "", summary: s, body: b, urgency: 1, when: t - min * 60000 });
        NotificationWatch.entries = [
            n("Messages", "Kai sent a message", "Pushed the patch for the tray popouts", 2),
            n("System", "42 packages can be updated", "Includes mesa 25.2", 46),
            n("Spectacle", "Screenshot saved", "~/Pictures/Screenshots/2026-09-11.png", 60 * 50)
        ];
        Surfaces.sessionKind = "promptShutDown";
        if (stage.which.startsWith("osd")) {
            OsdService.icon = stage.which === "osd" ? "audio-volume-medium" : "input-keyboard";
            OsdService.value = 62;
            OsdService.maxValue = 100;
            OsdService.showingProgress = stage.which === "osd";
            OsdService.text = stage.which === "osd" ? "" : "English (US)";
            OsdService.showing = true;
        }
    }

    Loader {
        anchors.fill: parent
        active: stage.which === "sidebar"
        sourceComponent: Item {
            Sidebar {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 16
                width: 396
            }
        }
    }

    // Toasts: the cards themselves, with stand-in notifications.
    Loader {
        anchors.fill: parent
        active: stage.which === "toasts"
        sourceComponent: Item {
            Component.onCompleted: ShellNotifications.deadlines = ({ 101: Date.now() + 3500 })
            readonly property var fake: (id, app, s, b, extra) => Object.assign({
                id: id, appName: app, appIcon: "", image: "", summary: s, body: b, urgency: 1,
                expireTimeout: -1, actions: [], dismiss: () => {}
            }, extra ?? {})
            Column {
                x: parent.width - 400
                y: 20
                width: 380
                spacing: 8
                NotificationCard { width: parent.width; notification: parent.parent.fake(101, "Messages", "Kai sent a message", "Pushed the patch for the tray popouts, take a look when you get a sec", { actions: [{ identifier: "reply", text: "Reply" }, { identifier: "read", text: "Mark read" }] }) }
                NotificationCard { width: parent.width; notification: parent.parent.fake(102, "System", "42 packages can be updated", "Includes linux-zen 6.16.4 and mesa 25.2") }
                NotificationCard { width: parent.width; notification: parent.parent.fake(103, "Power", "Battery low", "8% left · plug in soon", { urgency: 2 }) }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: stage.which === "keys"
        sourceComponent: KeysOverlay {}
    }

    Loader {
        anchors.fill: parent
        active: stage.which === "session"
        sourceComponent: SessionOverlay {}
    }

    Loader {
        anchors.fill: parent
        active: stage.which.startsWith("osd")
        sourceComponent: Item {
            OsdOverlay {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(parent.height * 0.12)
                height: implicitHeight
            }
        }
    }
}
