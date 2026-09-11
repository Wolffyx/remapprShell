pragma ComponentBehavior: Bound

// Notification history.
//
// Plasma keeps drawing every notification; this remembers them. The list is
// whatever the eavesdrop has seen since the shell started, newest first, and
// it is empty -- with a line saying why -- until the history is turned on.
//
// "Ask" hands one entry to `rmpr ask`, which opens the consent window on it.
// The widget never assembles anything itself: the CLI is the one code path
// that redacts and sends, and this is a button that runs it.

import QtQuick
import Quickshell
import qs.core
import qs.domain.config
import qs.domain.notifications
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

BarWidget {
    id: root

    readonly property bool showCount: root.widgetConfig?.showCount ?? true
    readonly property bool askable: ConfigStore.value("ai.enabled", false) === true
    readonly property int shown: 12

    tooltip: !NotificationWatch.enabled ? "Notification history is off"
           : NotificationWatch.unseen > 0 ? `${NotificationWatch.unseen} new since you last looked`
           : "Notification history"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function handleActivate(button) {
        root.popoutVisible = !root.popoutVisible;
        if (root.popoutVisible)
            NotificationWatch.markSeen();
    }

    function timeOf(when) {
        const d = new Date(when);
        const today = new Date();
        const sameDay = d.toDateString() === today.toDateString();
        return Qt.formatDateTime(d, sameDay ? "HH:mm" : "ddd HH:mm");
    }

    readonly property bool quiet: !NotificationWatch.enabled || ShellNotifications.dnd

    BarButton {
        id: button
        thickness: root.bar?.thickness ?? 40
        hovered: root.hovered
        active: root.popoutVisible
        size: Math.max(22, Math.round(40 * root.unit))
        glyph: root.quiet ? "notifications_off" : "notifications"
        fallback: root.quiet ? "notifications-disabled" : "notifications"
    }

    // Something unseen: a dot, or the count. Do not disturb silences it, as
    // it silences the popups.
    Rectangle {
        readonly property bool counting: root.showCount

        visible: NotificationWatch.unseen > 0 && !root.popoutVisible && !ShellNotifications.dnd
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
        Item {
            id: list

            readonly property var entries: NotificationWatch.entries.slice(0, root.shown)

            implicitWidth: 380
            implicitHeight: body.implicitHeight

            Column {
                id: body
                width: parent.width
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 8

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - clear.width - 8
                        text: NotificationWatch.entries.length > 0
                            ? `${NotificationWatch.entries.length} recent`
                            : "Notifications"
                        font.bold: true
                    }

                    IconButton {
                        id: clear
                        anchors.verticalCenter: parent.verticalCenter
                        visible: NotificationWatch.entries.length > 0
                        iconName: "edit-clear-history"
                        onActivated: NotificationWatch.clear()
                    }
                }

                // Only while this shell draws the popups: Plasma's own
                // do-not-disturb is in its applet.
                Row {
                    visible: ShellNotifications.active
                    width: parent.width
                    spacing: 8

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - dndToggle.width - 8
                        text: "Do not disturb"
                        font.pixelSize: 11
                    }

                    Toggle {
                        id: dndToggle
                        anchors.verticalCenter: parent.verticalCenter
                        checked: ShellNotifications.dnd
                        onToggled: value => ShellNotifications.setDnd(value ? "on" : "off")
                    }
                }

                PanelText {
                    visible: !NotificationWatch.enabled
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Theme.foregroundInactive
                    font.pixelSize: 11
                    text: `The history is off, so nothing is being kept. Turn it on under Notifications in the settings; ${ShellNotifications.active ? "this shell" : "Plasma"} keeps drawing them either way.`
                }

                PanelText {
                    visible: NotificationWatch.enabled && NotificationWatch.entries.length === 0
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Theme.foregroundInactive
                    font.pixelSize: 11
                    text: "Nothing yet. Notifications are remembered from the moment the shell starts, and only in memory."
                }

                Repeater {
                    model: list.entries

                    Rectangle {
                        id: row

                        required property var modelData
                        required property int index

                        width: body.width
                        height: line.implicitHeight + 12
                        radius: 6
                        color: rowHover.hovered ? Theme.hoverBackground : "transparent"

                        Row {
                            id: line
                            x: 6
                            y: 6
                            width: parent.width - 12
                            spacing: 10

                            PanelIcon {
                                implicitSize: 24
                                iconName: row.modelData.appIcon || "dialog-information"
                            }

                            Column {
                                width: parent.width - 24 - (ask.visible ? ask.width : 0) - parent.spacing * 2
                                spacing: 1

                                Row {
                                    width: parent.width
                                    spacing: 6

                                    PanelText {
                                        text: row.modelData.summary
                                        font.bold: true
                                        elide: Text.ElideRight
                                        width: parent.width - stamp.width - 6
                                    }

                                    PanelText {
                                        id: stamp
                                        text: root.timeOf(row.modelData.when)
                                        color: Theme.foregroundInactive
                                        font.pixelSize: 10
                                    }
                                }

                                PanelText {
                                    width: parent.width
                                    text: row.modelData.appName
                                    color: row.modelData.urgency >= 2 ? Theme.negative : Theme.foregroundInactive
                                    font.pixelSize: 10
                                }

                                PanelText {
                                    visible: row.modelData.body.length > 0
                                    width: parent.width
                                    text: row.modelData.body
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    font.pixelSize: 11
                                }
                            }

                            IconButton {
                                id: ask
                                visible: root.askable
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: "help-hint"
                                onActivated: Quickshell.execDetached([Branding.ctlBin, "ask",
                                    "--notification", String(row.index), "--review"])
                            }
                        }

                        HoverHandler { id: rowHover }
                    }
                }

                PanelText {
                    visible: NotificationWatch.entries.length > root.shown
                    width: parent.width
                    color: Theme.foregroundInactive
                    font.pixelSize: 10
                    text: `and ${NotificationWatch.entries.length - root.shown} older`
                }
            }
        }
    }
}
