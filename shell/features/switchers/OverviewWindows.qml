pragma ComponentBehavior: Bound

// The desktop under the selection, drawn large: what is selected said in
// words, then a card for each of its windows -- the window itself where KWin
// gives a picture, its application's icon over a tint where it does not --
// or, on an empty desktop, a line that says so.

import QtQuick
import qs.domain.theme
import qs.domain.windows
import qs.domain.windows.events
import qs.ui.primitives

Column {
    id: middle

    // The overview's, handed down: the desktop under the selection and its
    // windows, which of them is selected (-1 for the desktop itself), and
    // how the cards are to be drawn.
    required property var desk
    required property int deskIndex
    required property var deskWindows
    required property int winIndex
    required property bool hold
    required property bool showTitles
    required property int maxCardWidth

    // How a count of windows is said, the same here as on the strip.
    required property var countLabel

    // The pointer resting on a card, and a card clicked. The overview keeps
    // the selection and does the switching; the cards only ask.
    signal entered(int index)
    signal chosen(int index)

    spacing: 20

    // What is selected, said in words: with nothing but cards on
    // screen there is nowhere else to read what releasing the key
    // would do.
    Row {
        id: pills

        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Repeater {
            model: [
                middle.desk ? `Desktop ${middle.deskIndex + 1}${middle.desk.name ? ` · ${middle.desk.name}` : ""}`
                            : "No desktops",
                middle.countLabel(middle.deskWindows.length),
                middle.winIndex >= 0
                    ? (middle.hold ? "Release Meta to switch here and raise this window"
                                   : "Enter, or click, to switch here and raise this window")
                    : middle.deskWindows.length > 0
                        ? (middle.hold ? "Release Meta to switch here" : "Enter, or click, to switch here")
                        : (middle.hold ? "Release Meta for a clean desktop" : "Enter for a clean desktop")
            ]

            Rectangle {
                id: pill
                required property string modelData

                height: 34
                width: pillText.implicitWidth + 30
                radius: 17
                color: Theme.glass
                border.width: 1
                border.color: Theme.out

                PanelText {
                    id: pillText
                    anchors.centerIn: parent
                    text: pill.modelData
                    font.pixelSize: 14
                    color: Theme.fg
                }
            }
        }
    }

    // The cards. Three to a row at most, as wide as the room
    // allows, and never so wide that two windows look like a
    // gallery of one.
    Flickable {
        id: cardsArea

        width: parent.width
        height: middle.height - pills.height - middle.spacing
        contentHeight: cards.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Flow {
            id: cards

            width: parent.width
            spacing: 22

            // Centred while they fit, and scrolled when they do not:
            // a desktop with eight windows on it is two rows of cards
            // taller than the room between the header and the strip.
            y: Math.max(0, (cardsArea.height - cards.implicitHeight) / 2)

            // Centred across, too. Two cards of a capped width in a
            // three-card row sat against the left edge under a header
            // and pills that are both centred.
            readonly property int inRow: Math.max(1, Math.min(middle.deskWindows.length, cards.columns))
            x: Math.max(0, (cardsArea.width
                            - (cards.inRow * cards.cardWidth + cards.spacing * (cards.inRow - 1))) / 2)

            readonly property int columns: Math.max(1, Math.min(middle.deskWindows.length,
                                                                Math.floor(cards.width / 430)))
            readonly property real cardWidth: Math.min(middle.maxCardWidth,
                (cards.width - cards.spacing * (cards.columns - 1)) / cards.columns)

            Repeater {
                model: middle.deskWindows

                Rectangle {
                    id: card

                    required property var modelData
                    required property int index

                    readonly property bool selected: card.index === middle.winIndex

                    width: cards.cardWidth
                    height: 372
                    radius: Theme.radiusOf(22)
                    color: card.selected ? Theme.accC : Theme.s1
                    border.width: card.selected ? 2 : 1
                    border.color: card.selected ? Theme.acc : Theme.out
                    // The lift is a transform, not a `y`. A Flow
                    // positions both x and y of its children, so a
                    // card that sets its own y fights the positioner
                    // and the row lands on top of itself -- which is
                    // what "the apps list are moving one over each
                    // other" was. The switcher can set y because a
                    // Row positions x alone.
                    property real lift: card.selected ? 3 : 0
                    Behavior on lift { NumberAnimation { duration: 120 } }
                    transform: Translate { y: -card.lift }

                    // A colour per application, as the switcher's
                    // cards use, so the same program looks the same in
                    // both.
                    readonly property color tint: Qt.hsla(WindowEvents.tintHue(card.modelData?.appId),
                                                          0.34, Theme.dark ? 0.38 : 0.62, 1)

                    Rectangle {
                        id: preview

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        height: 296
                        radius: 14
                        clip: true
                        color: card.tint
                        opacity: card.modelData?.minimized ? 0.55 : 1

                        // The window itself where KWin gives a
                        // picture, and the application's icon over
                        // the card's own tint where it does not.
                        WindowThumbnail {
                            anchors.fill: parent
                            anchors.topMargin: middle.showTitles ? 34 : 0
                            windowId: card.modelData?.uuid ?? ""
                            iconName: WindowsService.iconFor(card.modelData)
                            iconFile: WindowsService.iconFileFor(card.modelData)
                            iconScale: 0.5
                            sourceAspect: WindowEvents.aspectOf(card.modelData)
                            // Only the card under the selection.
                            //
                            // Eleven windows meant eleven streams,
                            // and the list is rebuilt whenever a
                            // window opens or closes -- so streams
                            // were created and destroyed in bursts and
                            // PipeWire answered "target not found" for
                            // all of them. One stream at a time is
                            // also all a person is looking at.
                            live: card.selected && !card.modelData?.minimized
                        }

                        Rectangle {
                            visible: middle.showTitles
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 34
                            color: Qt.rgba(Theme.s1.r, Theme.s1.g, Theme.s1.b, 0.82)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                PanelIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 16
                                    iconName: WindowsService.iconFor(card.modelData)
                                    iconFile: WindowsService.iconFileFor(card.modelData)
                                }

                                PanelText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 30
                                    text: card.modelData?.title ?? ""
                                    elide: Text.ElideRight
                                    font.pixelSize: 12
                                    color: Theme.mut
                                }
                            }
                        }
                    }

                    Row {
                        anchors.top: preview.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        anchors.topMargin: 14
                        spacing: 12

                        Rectangle {
                            width: 42; height: 42; radius: 13
                            color: card.selected ? Theme.acc : Theme.s2

                            PanelIcon {
                                anchors.centerIn: parent
                                implicitSize: 23
                                iconName: WindowsService.iconFor(card.modelData)
                                iconFile: WindowsService.iconFileFor(card.modelData)
                            }
                        }

                        Column {
                            width: parent.width - 54
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            PanelText {
                                width: parent.width
                                text: WindowsService.appNameFor(card.modelData)
                                elide: Text.ElideRight
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                color: card.selected ? Theme.accCFg : Theme.fg
                            }

                            PanelText {
                                width: parent.width
                                text: card.modelData?.minimized ? "Minimised"
                                    : card.index === 0 ? "Top of the stack"
                                    : `${card.index} behind`
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                color: card.selected ? Theme.accCFg : Theme.mut
                            }
                        }
                    }

                    TapHandler {
                        onTapped: middle.chosen(card.index)
                    }
                    HoverHandler {
                        onHoveredChanged: if (hovered) middle.entered(card.index)
                    }
                }
            }
        }
    }

    // Nothing open here. Worth saying plainly: an empty desktop is
    // a thing people switch to on purpose.
    Column {
        visible: middle.deskWindows.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 14

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "window"
            fallback: "window"
            size: 56
            color: Theme.fg
            opacity: 0.8
        }

        PanelText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing open on this desktop"
            font.pixelSize: 17
            color: Theme.fg
        }
    }
}
