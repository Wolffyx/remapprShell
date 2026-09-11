pragma ComponentBehavior: Bound

// One popup: the application, the summary, the body as plain text, and the
// application's own actions -- plus "Ask" when AI assist is on, which is what
// the plan's second tier was for: an action no other daemon's popup could
// carry. A click on the text takes the default action, or closes the popup
// when there is none; right-click closes it. The pointer resting on it holds
// its time.

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

    implicitHeight: body.implicitHeight + 24
    radius: 10
    color: Theme.panelBackground
    border.width: card.critical ? 1 : 0
    border.color: Theme.negative

    HoverHandler {
        onHoveredChanged: if (card.notification) ShellNotifications.hold(card.notification.id, hovered)
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: card.notification?.dismiss()
    }

    Row {
        id: body

        x: 12
        y: 12
        width: card.width - 24
        spacing: 12

        Item {
            width: 36
            height: 36

            Image {
                anchors.fill: parent
                visible: card.icon.kind === "image"
                source: card.icon.kind === "image" ? card.icon.value : ""
                sourceSize: Qt.size(72, 72)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            PanelIcon {
                anchors.centerIn: parent
                visible: card.icon.kind === "name"
                implicitSize: 32
                iconName: card.icon.kind === "name" ? card.icon.value : ""
                fallbackName: "dialog-information"
            }
        }

        Column {
            width: body.width - 36 - body.spacing
            spacing: 4

            Row {
                width: parent.width
                spacing: 6

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - close.width - 6
                    text: card.notification?.appName ?? ""
                    textFormat: Text.PlainText
                    color: card.critical ? Theme.negative : Theme.foregroundInactive
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                IconButton {
                    id: close
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "window-close"
                    onActivated: card.notification?.dismiss()
                }
            }

            Column {
                width: parent.width
                spacing: 2

                PanelText {
                    width: parent.width
                    text: card.notification?.summary ?? ""
                    textFormat: Text.PlainText
                    font.bold: true
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
                    font.pixelSize: 12
                }

                TapHandler {
                    onTapped: if (card.notification) ShellNotifications.activate(card.notification)
                }
            }

            Flow {
                width: parent.width
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
                    iconName: "help-hint"
                    text: "Ask"
                    onActivated: ShellNotifications.ask(card.notification)
                }
            }
        }
    }
}
