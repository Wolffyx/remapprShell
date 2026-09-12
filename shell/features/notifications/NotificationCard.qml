pragma ComponentBehavior: Bound

// One popup, as the design's toasts: the application, the summary, the body as
// plain text, the application's own actions -- plus "Ask" when AI assist is
// on, which is what the plan's second tier was for: an action no other
// daemon's popup could carry -- and a bar that says how long it has left. A
// click on the text takes the default action, or closes the popup when there
// is none; right-click closes it. The pointer resting on it holds its time.

import QtQuick
import qs.domain.theme
import qs.domain.notifications
import qs.domain.notifications.popups
import qs.ui.primitives
import qs.ui.controls

Rectangle {
    id: card

    required property var notification

    readonly property var icon: Popups.iconOf(card.notification?.image ?? "", card.notification?.appIcon ?? "")
    readonly property bool critical: (card.notification?.urgency ?? 1) >= Popups.critical
    readonly property var actions: (card.notification?.actions ?? []).filter(a => a.identifier !== "default")

    // How much of its time is left, 0..1, from the deadline the service keeps;
    // -1 for a popup that stays until closed.
    readonly property real deadline: ShellNotifications.deadlines[card.notification?.id] ?? 0
    readonly property real span: Popups.timeoutFor(card.notification?.urgency ?? 1,
                                                   card.notification?.expireTimeout ?? -1,
                                                   ShellNotifications.timeoutMs)
    property real remaining: 1

    Timer {
        interval: 100
        repeat: true
        running: card.deadline > 0 && card.span > 0
        onTriggered: card.remaining = Math.max(0, Math.min(1, (card.deadline - Date.now()) / card.span))
    }

    implicitHeight: body.implicitHeight + 30
    radius: 22
    color: Theme.glass
    border.width: 1
    border.color: card.critical ? Theme.error : Theme.out

    HoverHandler {
        onHoveredChanged: if (card.notification) ShellNotifications.hold(card.notification.id, hovered)
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: card.notification?.dismiss()
    }

    Column {
        id: body

        x: 17
        y: 15
        width: card.width - 34
        spacing: 0

        Item {
            width: parent.width
            height: 24

            Item {
                id: iconBox
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20

                Image {
                    anchors.fill: parent
                    visible: card.icon.kind === "image"
                    source: card.icon.kind === "image" ? card.icon.value : ""
                    sourceSize: Qt.size(40, 40)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                PanelIcon {
                    anchors.fill: parent
                    visible: card.icon.kind === "name"
                    iconName: card.icon.kind === "name" ? card.icon.value : ""
                    fallbackName: "dialog-information"
                }

                Glyph {
                    anchors.centerIn: parent
                    visible: card.icon.kind !== "image" && card.icon.kind !== "name"
                    name: "notifications"
                    size: 19
                    color: Theme.acc
                }
            }

            PanelText {
                anchors.left: iconBox.right
                anchors.leftMargin: 10
                anchors.right: close.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: card.notification?.appName ?? ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.pixelSize: 13
                font.weight: Font.Medium
                color: card.critical ? Theme.error : Theme.fg
            }

            IconButton {
                id: close
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: 28
                glyph: "close"
                iconName: "window-close"
                color: Theme.mut
                onActivated: card.notification?.dismiss()
            }
        }

        Column {
            width: parent.width
            topPadding: 6
            spacing: 2

            PanelText {
                width: parent.width
                text: card.notification?.summary ?? ""
                textFormat: Text.PlainText
                font.pixelSize: 14
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            PanelText {
                width: parent.width
                visible: text.length > 0
                text: Popups.plain(card.notification?.body ?? "")
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: 5
                elide: Text.ElideRight
                font.pixelSize: 13
                color: Theme.mut
            }

            TapHandler {
                onTapped: if (card.notification) ShellNotifications.activate(card.notification)
            }
        }

        Flow {
            width: parent.width
            topPadding: 10
            spacing: 6
            visible: card.actions.length > 0 || ShellNotifications.askable

            Repeater {
                model: card.actions

                TextButton {
                    required property var modelData

                    text: modelData.text
                    onActivated: ShellNotifications.invoke(card.notification, modelData)
                }
            }

            TextButton {
                visible: ShellNotifications.askable
                glyph: "help"
                iconName: "help-hint"
                text: "Ask"
                onActivated: ShellNotifications.ask(card.notification)
            }
        }

        // How long it has left.
        Rectangle {
            visible: card.deadline > 0
            width: parent.width
            height: 3
            radius: 1.5
            color: Theme.alpha(Theme.fg, 0.12)

            Rectangle {
                width: parent.width * card.remaining
                height: parent.height
                radius: parent.radius
                color: Theme.acc
            }
        }

        Item { visible: card.deadline > 0; width: 1; height: 1 }
    }
}
