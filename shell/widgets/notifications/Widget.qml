pragma ComponentBehavior: Bound

// The bell, and the notification centre it opens.
//
// Plasma keeps drawing every notification; this remembers them. The list is
// whatever the eavesdrop has seen since the shell started, newest first, and
// it is empty -- with a line saying why, and a way to start it -- until the
// history is turned on. Grouped by application or as one stream by day
// (`notifications.centreStyle`), as the design has both; the arranging is
// qs.domain.notifications.centre, tested.
//
// "Ask" hands one entry to `rmpr ask`, which opens the consent window on it.
// The widget never assembles anything itself: the CLI is the one code path
// that redacts and sends, and this is a button that runs it.
//
// This file is the bell and what the centre asks of it. The centre is
// NotificationCentre, and its cards and rows the files beside it.

import QtQuick
import Quickshell
import qs.core
import qs.domain.config
import qs.domain.notifications
import qs.domain.theme
import qs.ui.primitives

BarWidget {
    id: root

    readonly property bool showCount: root.widgetConfig?.showCount ?? false
    readonly property bool askable: ConfigStore.value("ai.enabled", false) === true
    readonly property string style: ConfigStore.value("notifications.centreStyle", "grouped") === "stream" ? "stream" : "grouped"
    readonly property int shown: 40

    readonly property bool quiet: !NotificationWatch.enabled || DoNotDisturb.active

    tooltip: !NotificationWatch.enabled ? "Notification history is off"
           : DoNotDisturb.active ? "Do not disturb is on"
           : NotificationWatch.unseen > 0 ? `${NotificationWatch.unseen} new since you last looked`
           : "Notifications"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function handleActivate(button) {
        root.popoutVisible = !root.popoutVisible;
        if (root.popoutVisible)
            NotificationWatch.markSeen();
    }

    function ask(entry) {
        const index = NotificationWatch.entries.indexOf(entry);
        if (index >= 0)
            Quickshell.execDetached([Branding.ctlBin, "ask", "--notification", String(index), "--review"]);
    }

    BarButton {
        id: button
        thickness: root.barThickness
        hovered: root.hovered
        active: root.popoutVisible
        size: root.tileSize
        glyph: root.quiet ? "notifications_off" : "notifications"
        fallback: root.quiet ? "notifications-disabled" : "notifications"
    }

    // Something unseen: a dot, or the count. Do not disturb silences it, as
    // it silences the popups.
    Rectangle {
        readonly property bool counting: root.showCount

        visible: NotificationWatch.unseen > 0 && !root.popoutVisible && !DoNotDisturb.active
        x: button.width - width - Math.round(button.width * (counting ? 0.08 : 0.2))
        y: Math.round(button.height * (counting ? 0.08 : 0.18))
        width: counting ? Math.max(16, badge.implicitWidth + 8) : 10
        height: counting ? 16 : 10
        radius: height / 2
        color: Theme.acc
        border.width: 2
        border.color: Theme.surface

        PanelText {
            id: badge
            visible: parent.counting
            anchors.centerIn: parent
            text: NotificationWatch.unseen > 99 ? "99+" : String(NotificationWatch.unseen)
            color: Theme.accFg
            font.pixelSize: 9
            font.bold: true
        }
    }

    popout: Component {
        NotificationCentre { widget: root }
    }
}
