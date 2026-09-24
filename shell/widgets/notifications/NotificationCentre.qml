pragma ComponentBehavior: Bound

// The notification centre the bell opens: the history, newest first, grouped
// by application (GroupCard) or as one stream by day (StreamDay), as
// `notifications.centreStyle` says -- or, while the history is off, a line
// saying so and a way to start it.
//
// A PopoutColumn, like every other widget's popout -- this is the one that
// found out why a bare Column will not do (see PopoutColumn).

import QtQuick
import Quickshell
import qs.domain.config
import qs.domain.notifications
import qs.domain.notifications.centre
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

PopoutColumn {
    id: centre

    // The bell: how much of the history to show and in which style, whether
    // Ask is offered and what it does, and the popout that opening a
    // notification puts away.
    required property var widget

    readonly property var entries: NotificationWatch.entries.slice(0, centre.widget.shown)
    property real now: Date.now()

    // Midnight this morning, which is all the stream's days depend on. Handed
    // `now` itself, the days were worked out again on every tick of the timer
    // below, and the rows were kept only because the Repeater happened to find
    // the new list equal to the old one -- which it does, as of Qt 6.11.
    readonly property real today: {
        const d = new Date(centre.now);
        return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
    }

    readonly property var groups: centre.widget.style === "grouped" ? Centre.groups(centre.entries) : []
    readonly property var buckets: centre.widget.style === "stream" ? Centre.buckets(centre.entries, centre.today) : []

    // A group or a day by its place, as long as its name agrees, and by name
    // while the list is still moving under it. The Repeaters below are over
    // the names, so a new notification moves a card rather than making every
    // card again -- an opened-out group stays open.
    function groupAt(index, app) {
        const at = centre.groups[index];
        return at?.app === app ? at : (centre.groups.find(g => g.app === app) ?? { app: app, icon: "", entries: [] });
    }

    function bucketAt(index, label) {
        const at = centre.buckets[index];
        return at?.label === label ? at : (centre.buckets.find(b => b.label === label) ?? { label: label, entries: [] });
    }

    implicitWidth: 384
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
                model: ScriptModel { values: centre.groups.map(g => g.app) }

                GroupCard {
                    id: groupCard
                    // The application, and its place in the list.
                    required property string modelData
                    required property int index
                    widget: centre.widget
                    group: centre.groupAt(groupCard.index, groupCard.modelData)
                    now: centre.now
                }
            }

            Repeater {
                model: ScriptModel { values: centre.buckets.map(b => b.label) }

                StreamDay {
                    id: bucket

                    // The day's label, and its place in the list.
                    required property string modelData
                    required property int index

                    widget: centre.widget
                    day: centre.bucketAt(bucket.index, bucket.modelData)
                    width: list.width
                }
            }
        }
    }

    PanelText {
        visible: NotificationWatch.entries.length > centre.widget.shown
        width: parent.width
        color: Theme.mut
        font.pixelSize: 12
        text: `and ${NotificationWatch.entries.length - centre.widget.shown} older`
    }
}
