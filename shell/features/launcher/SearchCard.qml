pragma ComponentBehavior: Bound

// The built-in search's card: the field, what it finds, and the keys it
// answers to. An Item, so it can be drawn anywhere -- SearchOverlay puts it
// over the screen, a preview draws it in an ordinary window.

import QtQuick
import QtQuick.Controls
import qs.domain.launcher.apps
import qs.domain.launcher.providers
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: card

    required property BuiltinProvider provider

    function focusField() {
        field.forceActiveFocus();
    }

    implicitWidth: 760
    height: column.implicitHeight
    radius: Theme.radiusOf(26)
    color: Theme.glass
    border.width: 1
    border.color: Theme.out

    // Presses on the card are its own, not the scrim's behind it.
    MouseArea { anchors.fill: parent }

    Column {
        id: column
        width: parent.width

        Item {
            width: parent.width
            height: 70

            Glyph {
                id: lens
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 26
                color: Theme.acc
            }

            TextField {
                id: field
                anchors.left: lens.right
                anchors.leftMargin: 14
                anchors.right: hint.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                focus: true
                background: null
                color: Theme.fg
                selectionColor: Theme.accC
                selectedTextColor: Theme.accCFg
                placeholderText: `Search, or type ${card.provider.prefix} for actions`
                placeholderTextColor: Theme.mut
                font.family: Theme.fontFamily
                font.pixelSize: 22
                text: card.provider.query

                onTextChanged: {
                    card.provider.query = text;
                    card.provider.selectedIndex = 0;
                }

                Keys.onDownPressed: card.provider.moveSelection(1)
                Keys.onUpPressed: card.provider.moveSelection(-1)
                Keys.onReturnPressed: card.provider.activateSelected()
                Keys.onEnterPressed: card.provider.activateSelected()
                Keys.onEscapePressed: card.provider.close()

                // Pins what is selected, from the list rather than from a
                // settings page. Ctrl+P because P is what it does and Ctrl
                // is the only modifier a field being typed into can spare.
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                        card.provider.togglePin(card.provider.selectedApp);
                        event.accepted = true;
                    }
                }

                // Completes to the chosen result: an action's full name after
                // the prefix, an application's name.
                Keys.onTabPressed: {
                    const item = card.provider.results[card.provider.selectedIndex];
                    if (item?.kind === "action")
                        card.provider.query = `${card.provider.prefix}${item.action.id}`;
                    else if (item?.kind === "app")
                        card.provider.query = item.name;
                }
            }

            PanelText {
                id: hint
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                text: `${card.provider.prefix} actions`
                font.family: Theme.monoFamily
                font.pixelSize: 12
                color: Theme.mut
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.out
            }
        }

        Column {
            x: 10
            width: parent.width - 20
            topPadding: 10
            bottomPadding: 10
            spacing: 2

            Repeater {
                model: card.provider.results.slice(0, 9)

                // A row, under the heading of its kind when it is the first
                // of that kind. The heading is drawn inside the delegate
                // rather than as a second model, so the list stays flat: the
                // selection is an index, and Up and Down still step one row.
                Column {
                    id: group

                    required property var modelData
                    required property int index

                    width: parent.width

                    readonly property string heading: Results.headingAt(card.provider.results, group.index)

                    PanelText {
                        visible: group.heading.length > 0
                        leftPadding: 18
                        topPadding: group.index === 0 ? 2 : 10
                        bottomPadding: 4
                        text: group.heading.toUpperCase()
                        font.family: Theme.monoFamily
                        font.pixelSize: 11
                        font.letterSpacing: 1
                        color: Theme.mut
                    }

                Rectangle {
                    id: row

                    readonly property var modelData: group.modelData
                    readonly property int index: group.index
                    readonly property bool selected: row.index === card.provider.selectedIndex

                    width: parent.width
                    height: card.provider.dense ? 48 : 62
                    radius: Theme.radiusOf(16)
                    color: row.selected ? Theme.accC : (rowHover.hovered ? Theme.s2 : "transparent")

                    Item {
                        id: rowIcon
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28

                        PanelIcon {
                            anchors.fill: parent
                            // An open window carries an icon exactly as an
                            // application does, so this is asked of the row
                            // rather than of its kind.
                            visible: String(row.modelData.icon ?? "").length > 0
                            iconName: row.modelData.icon ?? ""
                        }

                        Glyph {
                            anchors.centerIn: parent
                            visible: String(row.modelData.icon ?? "").length === 0
                            name: row.modelData.glyph ?? ""
                            size: 24
                            color: row.selected ? Theme.acc : Theme.mut
                        }
                    }

                    Column {
                        anchors.left: rowIcon.right
                        anchors.leftMargin: 16
                        anchors.right: pin.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter

                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.modelData.name
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: row.selected ? Theme.accCFg : Theme.fg
                        }

                        PanelText {
                            visible: !card.provider.dense && text.length > 0
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.modelData.description ?? ""
                            font.pixelSize: 13
                            color: row.selected ? Theme.alpha(Theme.accCFg, 0.75) : Theme.mut
                        }
                    }

                    // Pinned, or pinnable: shown on the row being looked at,
                    // and on every pinned row whether or not it is.
                    Glyph {
                        id: pin

                        readonly property bool pinned: card.provider.isPinned(row.modelData.app)

                        anchors.right: enterBadge.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.modelData.kind === "app" && (pin.pinned || row.selected || rowHover.hovered)
                        name: pin.pinned ? "keep" : "keep_off"
                        size: 18
                        opacity: pin.pinned ? 1 : 0.55
                        color: row.selected ? Theme.accCFg : Theme.mut

                        TapHandler { onTapped: card.provider.togglePin(row.modelData.app) }
                    }

                    Rectangle {
                        id: enterBadge
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.selected
                        width: enterText.implicitWidth + 16
                        height: 22
                        radius: Theme.radiusOf(6)
                        color: Theme.s1

                        PanelText {
                            id: enterText
                            anchors.centerIn: parent
                            text: "ENTER"
                            font.family: Theme.monoFamily
                            font.pixelSize: 11
                            color: Theme.mut
                        }
                    }

                    HoverHandler {
                        id: rowHover
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: if (hovered) card.provider.selectedIndex = row.index
                    }
                    TapHandler { onTapped: card.provider.activate(row.modelData) }
                }
                }
            }

            PanelText {
                visible: card.provider.results.length === 0
                leftPadding: 16
                topPadding: 8
                bottomPadding: 8
                text: card.provider.query.length > 0 ? "No matches" : "Start typing"
                color: Theme.mut
            }
        }

        // The hints along the foot. A line above them rather than a filled
        // bar: the card is the surface, and a second one inside it is one
        // more background to read past.
        Rectangle {
            visible: card.provider.hints
            width: parent.width
            height: 42
            color: "transparent"

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.out
            }

            Row {
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 24

                Repeater {
                    model: ["↑↓ navigate", "⏎ run", "⇥ complete", "⌃P pin", "esc dismiss"]

                    PanelText {
                        required property string modelData
                        text: modelData
                        font.pixelSize: 12
                        color: Theme.mut
                    }
                }
            }
        }
    }
}
