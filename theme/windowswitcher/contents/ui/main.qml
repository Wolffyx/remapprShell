/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Alt+Tab, drawn as the Meridian design draws it.

    KWin draws this; only its appearance is ours. `TabBoxSwitcher` is the
    interface KWin drives -- it sets `model` and `currentIndex` and reads back
    `currentIndex` when the switcher chooses -- so those names are exactly as
    KWin expects and everything else is presentation.

    What KWin offers a layout is `caption`, `icon`, `minimized` and `windowId`,
    and nothing else: there are no window previews here, because KWin does not
    advertise the screencast protocol to ordinary clients (see "No window
    thumbnails" in docs/handoff.md). The design's cards are tinted panels with
    the application's icon over them rather than photographs of the windows,
    which is what it asks for and all that can be drawn.

    Colours come from the active colour scheme through Kirigami.Theme, which is
    the whole point of shipping one: this matches the panel without either
    knowing about the other.
*/

// The base type lives in KWin's own qrc and cannot be resolved by the linter,
// so its properties would otherwise all read as unqualified access.
// qmllint disable unqualified
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

KWin.TabBoxSwitcher {
    id: tabBox

    currentIndex: cards.currentIndex

    // The design's row: a card 196 wide with a 118-tall panel above its name.
    readonly property int cardWidth: 196
    readonly property int panelHeight: 118
    readonly property int gap: 14
    readonly property int pad: 26
    readonly property int radius: 18

    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color ink: Kirigami.Theme.textColor
    readonly property color inkMuted: Kirigami.Theme.disabledTextColor
    readonly property color surface: Kirigami.Theme.backgroundColor
    readonly property color outline: Qt.rgba(tabBox.ink.r, tabBox.ink.g, tabBox.ink.b, 0.12)

    // A colour per application, so two windows of one program look alike and
    // two programs do not. Hashed from the caption because that is the only
    // stable string a layout is given.
    function tintFor(text) {
        let h = 0;
        const s = String(text ?? "");
        for (let i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 360;
        return Qt.hsla(h / 360, 0.34, Kirigami.Theme.backgroundColor.hslLightness > 0.5 ? 0.62 : 0.38, 1);
    }

    PlasmaCore.Dialog {
        id: dialog

        location: PlasmaCore.Types.Floating
        visible: tabBox.visible
        flags: Qt.Popup | Qt.X11BypassWindowManagerHint

        x: tabBox.screenGeometry.x + (tabBox.screenGeometry.width - dialog.width) / 2
        y: tabBox.screenGeometry.y + (tabBox.screenGeometry.height - dialog.height) / 2

        mainItem: Item {
            id: content

            // Never wider than most of the screen: with thirty windows open
            // the row scrolls rather than running off both edges.
            readonly property int maxWidth: tabBox.screenGeometry.width * 0.86

            // `contentWidth` is the row as laid out -- the cards plus their
            // spacing. It was `implicitContentWidth`, which no ListView has:
            // the sum came out NaN, the dialog had no width to be given, and
            // KWin's switcher drew nothing at all on every machine this
            // package was selected on. qmllint said so from the start
            // ("Did you mean implicitWidth?") and it was read as noise about
            // KWin's own unresolvable types.
            implicitWidth: Math.min(content.maxWidth,
                                    cards.contentWidth + 2 * tabBox.pad)
            implicitHeight: header.height + cards.height + footer.height + 3 * tabBox.pad / 2

            // ---- header: what this is, and that Alt is still held ----------
            Item {
                id: header

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: tabBox.pad / 2
                height: 34

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Kirigami.Icon {
                        width: 20; height: 20
                        source: "preferences-system-windows"
                        color: tabBox.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    PlasmaComponents3.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Windows"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                        font.weight: Font.Medium
                        color: tabBox.ink
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
                        width: countLabel.implicitWidth + 22
                        radius: height / 2
                        color: Qt.rgba(tabBox.accent.r, tabBox.accent.g, tabBox.accent.b, 0.16)

                        PlasmaComponents3.Label {
                            id: countLabel
                            anchors.centerIn: parent
                            text: `${cards.count} open · most recent first`
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.weight: Font.Medium
                            color: tabBox.accent
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    width: heldRow.implicitWidth + 24
                    radius: height / 2
                    color: Qt.rgba(tabBox.ink.r, tabBox.ink.g, tabBox.ink.b, 0.06)
                    border.width: 1
                    border.color: tabBox.outline

                    Row {
                        id: heldRow
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7; height: 7; radius: 4
                            color: tabBox.accent
                        }
                        PlasmaComponents3.Label {
                            text: "Alt held"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.weight: Font.Medium
                            color: tabBox.ink
                        }
                    }
                }
            }

            // ---- the cards -------------------------------------------------
            ListView {
                id: cards

                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: tabBox.pad / 2
                anchors.leftMargin: tabBox.pad / 2
                anchors.rightMargin: tabBox.pad / 2

                height: tabBox.panelHeight + 78
                orientation: ListView.Horizontal
                spacing: tabBox.gap
                clip: true
                focus: true
                boundsBehavior: Flickable.StopAtBounds
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: width / 2 - tabBox.cardWidth
                preferredHighlightEnd: width / 2 + tabBox.cardWidth
                highlightMoveDuration: Kirigami.Units.shortDuration

                model: tabBox.model

                delegate: Item {
                    id: entry

                    required property int index
                    required property string caption
                    required property var icon
                    required property bool minimized
                    required property var windowId

                    readonly property bool selected: entry.index === cards.currentIndex

                    width: tabBox.cardWidth
                    height: cards.height

                    Rectangle {
                        id: card

                        // The selected card lifts. Through a property of its
                        // own: a Behavior cannot be attached to a member of a
                        // grouped property, and `Behavior on anchors.topMargin`
                        // is a load-time error that takes the whole switcher
                        // with it -- which looks exactly like Alt+Tab doing
                        // nothing at all.
                        property real lift: entry.selected ? 0 : 4
                        Behavior on lift { NumberAnimation { duration: Kirigami.Units.shortDuration } }

                        anchors.fill: parent
                        anchors.topMargin: card.lift
                        radius: tabBox.radius
                        color: entry.selected
                               ? Qt.rgba(tabBox.accent.r, tabBox.accent.g, tabBox.accent.b, 0.18)
                               : Qt.rgba(tabBox.ink.r, tabBox.ink.g, tabBox.ink.b, 0.05)
                        border.width: entry.selected ? 2 : 1
                        border.color: entry.selected ? tabBox.accent : tabBox.outline
                        opacity: entry.minimized && !entry.selected ? 0.65 : 1

                        // The tinted panel, with the window's own icon over it
                        // at a size that reads as artwork rather than a badge.
                        Rectangle {
                            id: panel

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            height: tabBox.panelHeight
                            radius: 12
                            clip: true
                            color: tabBox.tintFor(entry.caption)

                            // The icon, large and faint, behind whatever the
                            // preview turns out to be: a window KWin has no
                            // picture of still reads as that application.
                            Kirigami.Icon {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: -12
                                anchors.bottomMargin: -18
                                width: 96; height: 96
                                source: entry.icon
                                opacity: 0.38
                            }

                            // The window itself. KWin renders this for its own
                            // switcher, which is the one place a preview costs
                            // nothing: an ordinary client cannot get one
                            // without speaking the screencast protocol in C++
                            // and feeding PipeWire, which is what every other
                            // shell that shows previews is doing.
                            KWin.WindowThumbnail {
                                anchors.fill: parent
                                anchors.topMargin: 22
                                wId: entry.windowId
                                opacity: entry.minimized ? 0.55 : 1
                            }

                            // The design's little title strip along the top.
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 22
                                color: Qt.rgba(tabBox.surface.r, tabBox.surface.g, tabBox.surface.b, 0.82)

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 5

                                    Kirigami.Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 11; height: 11
                                        source: entry.icon
                                    }
                                    PlasmaComponents3.Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 24
                                        text: entry.caption
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize - 1
                                        color: tabBox.inkMuted
                                    }
                                }
                            }
                        }

                        // The name under it, with the icon in a chip.
                        Row {
                            anchors.top: panel.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            anchors.topMargin: 11
                            spacing: 10

                            Rectangle {
                                width: 36; height: 36; radius: 12
                                color: entry.selected ? tabBox.accent
                                                      : Qt.rgba(tabBox.ink.r, tabBox.ink.g, tabBox.ink.b, 0.07)

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: entry.icon
                                }
                            }

                            Column {
                                width: parent.width - 46
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                PlasmaComponents3.Label {
                                    width: parent.width
                                    text: entry.caption
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    font.weight: Font.Medium
                                    color: tabBox.ink
                                }
                                PlasmaComponents3.Label {
                                    width: parent.width
                                    text: entry.minimized ? "Minimised" : "Open"
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    color: tabBox.inkMuted
                                }
                            }
                        }
                    }

                    TapHandler {
                        onTapped: {
                            cards.currentIndex = entry.index;
                            tabBox.model.activate(entry.index);
                        }
                    }
                }

                Connections {
                    target: tabBox
                    function onCurrentIndexChanged(): void {
                        cards.currentIndex = tabBox.currentIndex;
                    }
                }
            }

            // ---- footer: the selected window, and the keys ------------------
            Item {
                id: footer

                anchors.top: cards.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: tabBox.pad / 2
                anchors.topMargin: 14
                height: 40

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: tabBox.outline
                }

                PlasmaComponents3.Label {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: parent.width * 0.5
                    text: cards.currentItem?.caption ?? "No open windows"
                    textFormat: Text.PlainText
                    elide: Text.ElideMiddle
                    font.weight: Font.Medium
                    color: tabBox.ink
                }

                Row {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: 8

                    Repeater {
                        model: [
                            { key: "Tab", what: "next" },
                            { key: "Shift+Tab", what: "back" },
                            { key: "Alt ↑", what: "focus" },
                            { key: "Esc", what: "cancel" }
                        ]

                        delegate: Row {
                            required property var modelData
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 22
                                width: keyLabel.implicitWidth + 18
                                radius: 8
                                color: Qt.rgba(tabBox.ink.r, tabBox.ink.g, tabBox.ink.b, 0.06)
                                border.width: 1
                                border.color: tabBox.outline

                                PlasmaComponents3.Label {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    font.weight: Font.Medium
                                    color: tabBox.ink
                                }
                            }
                            PlasmaComponents3.Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.what
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                color: tabBox.inkMuted
                                rightPadding: 6
                            }
                        }
                    }
                }
            }

            PlasmaComponents3.Label {
                anchors.centerIn: parent
                visible: cards.count === 0
                textFormat: Text.PlainText
                opacity: 0.7
                text: "No open windows"
            }

            // Key handling belongs on the outer item: on the list view it is
            // lost between invocations, which shows up as Alt+Tab working the
            // first time and not the second.
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    cards.decrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    cards.incrementCurrentIndex();
                    event.accepted = true;
                }
            }
        }
    }
}
