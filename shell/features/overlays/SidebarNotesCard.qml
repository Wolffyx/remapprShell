pragma ComponentBehavior: Bound

// The sidebar's card for the latest notifications, from the history. Folded,
// three; open, ten -- and a click opens whatever the notification was about.

import QtQuick
import Quickshell
import qs.domain.notifications
import qs.domain.notifications.centre
import qs.domain.surfaces
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

SidebarCard {
    id: noteCard

    // The sidebar's clock, which every card that tells the time shares.
    required property SystemClock clock

    cardId: "notifications"
    title: "Notifications"
    glyph: "notifications"

    readonly property int shown: noteCard.open ? 10 : 3

    content: [
        Hint {
            visible: !NotificationWatch.enabled || NotificationWatch.entries.length === 0
            text: NotificationWatch.enabled ? "Nothing recent."
                : "The history is off; Settings → Notifications keeps one."
            lineHeight: 1
        },

        Repeater {
            model: NotificationWatch.entries.slice(0, noteCard.shown)

            Column {
                id: note
                required property var modelData
                width: parent.width
                spacing: 2

                Item {
                    width: parent.width
                    height: 18

                    PanelText {
                        width: parent.width - when.width - 8
                        elide: Text.ElideRight
                        text: note.modelData.summary
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    PanelText {
                        id: when
                        anchors.right: parent.right
                        text: Centre.ago(note.modelData.when, noteCard.clock.date.getTime())
                        font.family: Theme.monoFamily
                        font.pixelSize: 11
                        color: Theme.mut
                    }
                }

                PanelText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: note.modelData.appName
                    font.pixelSize: 12
                    color: Theme.mut
                }

                HoverHandler { cursorShape: NotificationWatch.openable(note.modelData) ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler {
                    enabled: NotificationWatch.openable(note.modelData)
                    onTapped: {
                        NotificationWatch.open(note.modelData);
                        Surfaces.closeAll();
                    }
                }
            }
        }
    ]

    extra: Column {
        spacing: 12

        TextButton {
            visible: NotificationWatch.entries.length > 0
            glyph: "clear_all"
            iconName: "edit-clear-history"
            text: "Clear"
            onActivated: NotificationWatch.clear()
        }
    }
}
