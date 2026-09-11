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

    implicitWidth: 24
    implicitHeight: 24

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

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: (hover.hovered || root.popoutVisible) ? PlasmaColors.hoverBackground : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        PanelIcon {
            anchors.centerIn: parent
            implicitSize: 18
            iconName: NotificationWatch.enabled ? "notifications" : "notifications-disabled"
        }

        Rectangle {
            visible: root.showCount && NotificationWatch.unseen > 0 && !root.popoutVisible
            anchors.right: parent.right
            anchors.top: parent.top
            width: Math.max(14, badge.implicitWidth + 6)
            height: 14
            radius: 7
            color: PlasmaColors.accent

            PanelText {
                id: badge
                anchors.centerIn: parent
                text: NotificationWatch.unseen > 99 ? "99+" : String(NotificationWatch.unseen)
                color: PlasmaColors.background
                font.pixelSize: 9
                font.bold: true
            }
        }

        HoverHandler { id: hover }
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

                PanelText {
                    visible: !NotificationWatch.enabled
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: PlasmaColors.foregroundInactive
                    font.pixelSize: 11
                    text: "The history is off, so nothing is being kept. Turn it on under Notification history in the settings; Plasma keeps drawing them either way."
                }

                PanelText {
                    visible: NotificationWatch.enabled && NotificationWatch.entries.length === 0
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: PlasmaColors.foregroundInactive
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
                        color: rowHover.hovered ? PlasmaColors.hoverBackground : "transparent"

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
                                        color: PlasmaColors.foregroundInactive
                                        font.pixelSize: 10
                                    }
                                }

                                PanelText {
                                    width: parent.width
                                    text: row.modelData.appName
                                    color: row.modelData.urgency >= 2 ? PlasmaColors.negative : PlasmaColors.foregroundInactive
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
                    color: PlasmaColors.foregroundInactive
                    font.pixelSize: 10
                    text: `and ${NotificationWatch.entries.length - root.shown} older`
                }
            }
        }
    }
}
