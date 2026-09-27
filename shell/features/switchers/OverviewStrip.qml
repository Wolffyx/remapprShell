pragma ComponentBehavior: Bound

// Along the bottom of the overview: every desktop, with a glance at what is
// on it, a button to take one away, and one more to make a new one.

import QtQuick
import qs.domain.theme
import qs.domain.desktops
import qs.domain.windows
import qs.ui.primitives

Rectangle {
    id: strip

    // The overview's, handed down: every desktop, the one under the
    // selection, and the window selected on it (-1 for none).
    required property var desks
    required property var desk
    required property int deskIndex
    required property var deskWindows
    required property int winIndex

    // How a desktop's windows are found and how many are said: the
    // overview's own, so the strip and the cards above cannot disagree.
    required property var windowsOn
    required property var countLabel

    // The pointer resting on a desktop, a desktop clicked, and its remove
    // button. The overview keeps the selection and acts; the strip only asks.
    signal entered(int index)
    signal chosen(int index)
    signal removeAsked(int index)

    height: 196
    radius: Theme.radiusOf(24)
    color: Theme.glass
    border.width: 1
    border.color: Theme.out

    Row {
        id: stripTitle

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 18
        spacing: 12

        PanelText {
            text: "ALL DESKTOPS"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 0.8
            color: Theme.mut
        }

        PanelText {
            text: strip.winIndex >= 0 && strip.deskWindows[strip.winIndex]
                ? (strip.deskWindows[strip.winIndex].title ?? "")
                : (strip.desk ? `Desktop ${strip.deskIndex + 1}${strip.desk.name ? ` · ${strip.desk.name}` : ""}` : "")
            elide: Text.ElideRight
            width: strip.width - 220
            font.pixelSize: 13
            color: Theme.fg
        }
    }

    Row {
        id: deskRow

        anchors.top: stripTitle.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 18
        anchors.topMargin: 12
        spacing: 14

        readonly property real cardWidth: {
            const n = Math.max(1, strip.desks.length);
            const room = deskRow.width - newDesk.width - deskRow.spacing * n;
            return Math.max(96, Math.min(240, room / n));
        }

        Repeater {
            model: strip.desks

            Rectangle {
                id: deskCard

                required property var modelData
                required property int index

                readonly property bool selected: deskCard.index === strip.deskIndex
                readonly property bool current: deskCard.modelData?.id === Desktops.currentId
                readonly property var deskWins: strip.windowsOn(deskCard.modelData?.id ?? "")

                width: deskRow.cardWidth
                height: 148
                radius: Theme.radiusOf(18)
                color: deskCard.selected ? Theme.accC : Theme.s2
                border.width: deskCard.selected ? 2 : 1
                border.color: deskCard.selected ? Theme.acc : Theme.out

                // A glance at what is on it: the applications, in
                // stacking order, as many as fit.
                Rectangle {
                    id: deskPreview

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    height: 84
                    radius: 12
                    clip: true
                    color: Theme.s1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 7

                        Repeater {
                            model: deskCard.deskWins.slice(0, 3)

                            Rectangle {
                                id: glance
                                required property var modelData

                                // Sized against the preview, not
                                // `parent`: a Repeater delegate's
                                // parent is null until it is
                                // reparented, which is a TypeError
                                // per tile and a tile of no height.
                                width: (deskPreview.width - 16 - 2 * 7) / 3
                                height: deskPreview.height - 16
                                radius: 8
                                color: Theme.glass
                                border.width: 1
                                border.color: Theme.out

                                PanelIcon {
                                    anchors.centerIn: parent
                                    implicitSize: 19
                                    iconName: WindowsService.iconFor(glance.modelData)
                                    iconFile: WindowsService.iconFileFor(glance.modelData)
                                }
                            }
                        }
                    }

                    PanelText {
                        anchors.centerIn: parent
                        visible: deskCard.deskWins.length === 0
                        text: "Empty"
                        font.pixelSize: 12
                        color: Theme.mut
                    }
                }

                Row {
                    anchors.top: deskPreview.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    anchors.topMargin: 10
                    spacing: 9

                    Rectangle {
                        width: 26; height: 26; radius: 9
                        color: deskCard.current ? Theme.acc : Theme.s1

                        PanelText {
                            anchors.centerIn: parent
                            text: String(deskCard.index + 1)
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: deskCard.current ? Theme.accFg : Theme.mut
                        }
                    }

                    Column {
                        width: parent.width - 44
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        PanelText {
                            width: parent.width
                            text: deskCard.modelData?.name ?? `Desktop ${deskCard.index + 1}`
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: deskCard.selected ? Theme.accCFg : Theme.fg
                        }

                        PanelText {
                            width: parent.width
                            text: strip.countLabel(deskCard.deskWins.length)
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: deskCard.selected ? Theme.accCFg : Theme.mut
                        }
                    }
                }

                // Taking one away, where the pointer already is.
                // Kept out of the way until the card is hovered,
                // and absent on the last desktop, which KWin will
                // not remove.
                Rectangle {
                    id: removeButton

                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    width: 24; height: 24
                    radius: 12
                    color: removeHover.hovered ? Theme.error : Theme.s1
                    opacity: (deskHover.hovered || removeHover.hovered) && strip.desks.length > 1 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 90 } }

                    Glyph {
                        anchors.centerIn: parent
                        name: "close"
                        fallback: "window-close"
                        size: 15
                        color: removeHover.hovered ? Theme.errorFg : Theme.mut
                    }

                    HoverHandler { id: removeHover }
                    TapHandler {
                        enabled: removeButton.opacity > 0
                        onTapped: strip.removeAsked(deskCard.index)
                    }
                }

                TapHandler {
                    onTapped: strip.chosen(deskCard.index)
                }
                HoverHandler {
                    id: deskHover
                    onHoveredChanged: if (hovered) strip.entered(deskCard.index)
                }
            }
        }

        // One more desktop. KWin numbers and names them; this asks
        // for one at the end and lets KWin do both.
        Rectangle {
            id: newDesk

            width: 150
            height: 148
            radius: Theme.radiusOf(18)
            color: "transparent"
            border.width: 2
            border.color: Theme.out

            Column {
                anchors.centerIn: parent
                spacing: 8

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "add"
                    fallback: "list-add"
                    size: 26
                    color: Theme.mut
                }

                PanelText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "New desktop"
                    font.pixelSize: 12
                    color: Theme.mut
                }
            }

            TapHandler {
                onTapped: Desktops.create()
            }
        }
    }
}
