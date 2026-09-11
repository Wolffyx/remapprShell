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

import QtQuick
import Quickshell
import qs.core
import qs.domain.config
import qs.domain.notifications
import qs.domain.notifications.centre
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

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

    // An application's icon as a notification names it -- a theme name or a
    // path -- or the bell.
    component NoteIcon: Item {
        id: icon

        property string source: ""
        property real size: 18
        readonly property bool isPath: icon.source.startsWith("/") || icon.source.startsWith("file:")

        implicitWidth: icon.size
        implicitHeight: icon.size

        PanelIcon {
            anchors.fill: parent
            visible: icon.source.length > 0
            iconName: icon.isPath ? "" : icon.source
            iconFile: icon.isPath ? icon.source : ""
        }

        Glyph {
            anchors.centerIn: parent
            visible: icon.source.length === 0
            name: "notifications"
            size: icon.size
            color: Theme.acc
        }
    }

    // One application's notifications: the latest on a card, the rest
    // stacked behind it until it is opened out.
    component GroupCard: Item {
        id: card

        required property var modelData
        required property real now
        property bool expanded: false

        readonly property var entries: card.modelData.entries
        readonly property int count: card.entries.length
        readonly property bool stacked: card.count > 1 && !card.expanded

        width: parent ? parent.width : 0
        height: face.height + (card.stacked ? 8 : 0)

        Rectangle {
            visible: card.stacked
            x: 12
            y: face.height - 30
            width: parent.width - 24
            height: 38
            radius: 18
            color: Theme.s2
        }

        Rectangle {
            id: face
            width: parent.width
            height: body.implicitHeight + 28
            radius: 20
            color: Theme.s1
            border.width: 1
            border.color: Theme.out

            Column {
                id: body
                x: 16
                y: 14
                width: parent.width - 32
                spacing: 0

                Item {
                    width: parent.width
                    height: 20

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        NoteIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: card.modelData.icon
                        }

                        PanelText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.modelData.app
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: card.count > 1
                            width: countText.implicitWidth + 14
                            height: 18
                            radius: 9
                            color: Theme.accC

                            PanelText {
                                id: countText
                                anchors.centerIn: parent
                                text: String(card.count)
                                font.pixelSize: 11
                                color: Theme.accCFg
                            }
                        }
                    }

                    PanelText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Centre.ago(card.entries[0]?.when, card.now)
                        font.family: Theme.monoFamily
                        font.pixelSize: 11
                        color: Theme.mut
                    }
                }

                Repeater {
                    model: card.expanded ? card.entries.slice(0, 8) : card.entries.slice(0, 1)

                    Column {
                        id: note

                        required property var modelData
                        required property int index

                        width: body.width
                        topPadding: 10

                        Rectangle {
                            visible: note.index > 0
                            width: parent.width
                            height: 1
                            color: Theme.out
                        }

                        Item { visible: note.index > 0; width: 1; height: 8 }

                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: note.modelData.summary
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: note.modelData.urgency >= 2 ? Theme.error : Theme.fg
                        }

                        PanelText {
                            visible: note.modelData.body.length > 0
                            width: parent.width
                            topPadding: 3
                            text: note.modelData.body
                            wrapMode: Text.WordWrap
                            maximumLineCount: card.expanded ? 4 : 2
                            elide: Text.ElideRight
                            font.pixelSize: 13
                            lineHeight: 1.15
                            color: Theme.mut
                        }
                    }
                }

                Row {
                    visible: root.askable || card.count > 1
                    topPadding: 12
                    spacing: 8

                    TextButton {
                        visible: card.count > 1
                        text: card.expanded ? "Show less" : `${card.count - 1} more`
                        onActivated: card.expanded = !card.expanded
                    }

                    TextButton {
                        visible: root.askable
                        glyph: "help"
                        iconName: "help-hint"
                        text: "Ask"
                        onActivated: root.ask(card.entries[0])
                    }
                }
            }
        }
    }

    popout: Component {
        Column {
            id: centre

            readonly property var entries: NotificationWatch.entries.slice(0, root.shown)
            property real now: Date.now()

            width: 384
            spacing: 14

            Timer {
                interval: 30000
                running: true
                repeat: true
                onTriggered: centre.now = Date.now()
            }

            Item {
                width: parent.width
                height: 34

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    font.pixelSize: 18
                    font.weight: Font.Medium
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    TextButton {
                        text: "Do not disturb"
                        checked: DoNotDisturb.active
                        onActivated: DoNotDisturb.toggle()
                    }

                    TextButton {
                        visible: NotificationWatch.entries.length > 0
                        text: "Clear all"
                        onActivated: NotificationWatch.clear()
                    }
                }
            }

            // Off: say so, and offer to start it.
            Column {
                visible: !NotificationWatch.enabled
                width: parent.width
                spacing: 12

                PanelText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Theme.mut
                    font.pixelSize: 13
                    lineHeight: 1.2
                    text: `The history is off, so nothing is being kept. ${DoNotDisturb.shellDraws ? "This shell" : "Plasma"} draws every notification either way; the history remembers them, in memory only, until the shell stops.`
                }

                TextButton {
                    primary: true
                    glyph: "history"
                    iconName: "view-history"
                    text: "Keep a history"
                    onActivated: ConfigStore.set("notifications.history", true)
                }
            }

            PanelText {
                visible: NotificationWatch.enabled && NotificationWatch.entries.length === 0
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.mut
                font.pixelSize: 13
                text: "Nothing yet. Notifications are remembered from the moment the shell starts, and only in memory."
            }

            Flickable {
                id: scroller
                visible: centre.entries.length > 0
                width: parent.width
                height: Math.min(contentHeight, 560)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: list
                    width: scroller.width
                    spacing: 12

                    Repeater {
                        model: root.style === "grouped" ? Centre.groups(centre.entries) : []

                        GroupCard { now: centre.now }
                    }

                    Repeater {
                        model: root.style === "stream" ? Centre.buckets(centre.entries, centre.now) : []

                        Column {
                            id: bucket

                            required property var modelData

                            width: list.width

                            MenuTitle {
                                leftPadding: 0
                                text: bucket.modelData.label
                            }

                            Repeater {
                                model: bucket.modelData.entries

                                Item {
                                    id: line

                                    required property var modelData
                                    required property int index

                                    width: bucket.width
                                    height: lineBody.implicitHeight + 24

                                    NoteIcon {
                                        y: 13
                                        size: 20
                                        source: line.modelData.appIcon ?? ""
                                    }

                                    Column {
                                        id: lineBody
                                        x: 34
                                        y: 12
                                        width: parent.width - 34

                                        Item {
                                            width: parent.width
                                            height: summary.implicitHeight

                                            PanelText {
                                                id: summary
                                                width: parent.width - stamp.width - 8
                                                elide: Text.ElideRight
                                                text: line.modelData.summary
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                                color: line.modelData.urgency >= 2 ? Theme.error : Theme.fg
                                            }

                                            PanelText {
                                                id: stamp
                                                anchors.right: parent.right
                                                text: Qt.formatDateTime(new Date(line.modelData.when), "HH:mm")
                                                font.family: Theme.monoFamily
                                                font.pixelSize: 11
                                                color: Theme.mut
                                            }
                                        }

                                        PanelText {
                                            visible: line.modelData.body.length > 0
                                            width: parent.width
                                            topPadding: 2
                                            text: line.modelData.body
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            font.pixelSize: 13
                                            color: Theme.mut
                                        }
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 1
                                        color: Theme.out
                                        visible: line.index < bucket.modelData.entries.length - 1
                                    }

                                    HoverHandler { id: lineHover }

                                    IconButton {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        visible: root.askable && lineHover.hovered
                                        size: 30
                                        glyph: "help"
                                        iconName: "help-hint"
                                        onActivated: root.ask(line.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            PanelText {
                visible: NotificationWatch.entries.length > root.shown
                width: parent.width
                color: Theme.mut
                font.pixelSize: 12
                text: `and ${NotificationWatch.entries.length - root.shown} older`
            }
        }
    }
}
