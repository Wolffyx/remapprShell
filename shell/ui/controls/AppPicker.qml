pragma ComponentBehavior: Bound

// Choosing one installed application: a search field over a list of them,
// drawn in place -- under the setting it is for -- rather than as a window
// of its own.
//
// Typing searches the way the launcher does (Apps.search): a name, a word of
// its description, its keywords or its binary. With nothing typed `preferred`
// comes first -- the system monitors, for the monitor setting -- then every
// application A to Z.
//
//   Up, Down, PageUp, PageDown   move
//   Return                       choose
//   Escape                       put it away without choosing

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.domain.launcher.apps
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: root

    // Desktop entry ids shown first while nothing is typed.
    property var preferred: []
    // The id already chosen, if any: marked in the list.
    property string currentId: ""
    property string placeholder: "Search installed applications"
    property int rows: 6

    signal picked(var app)
    signal cancelled

    readonly property int rowHeight: 40
    readonly property var results: Apps.search(DesktopEntries.applications.values, field.text, root.preferred)
    property int index: 0

    function focusField() {
        field.forceActiveFocus();
    }

    function go(i) {
        root.index = Math.max(0, Math.min(root.results.length - 1, i));
        list.positionViewAtIndex(root.index, ListView.Contain);
    }

    function choose(app) {
        if (app)
            root.picked(app);
    }

    implicitHeight: column.implicitHeight + 20
    radius: Theme.radiusTiny + 3
    color: Theme.s1
    border.width: 1
    border.color: Theme.out

    Component.onCompleted: Qt.callLater(root.focusField)

    Column {
        id: column
        x: 10
        y: 10
        width: parent.width - 20
        spacing: 8

        Item {
            width: parent.width
            height: 36

            Rectangle {
                anchors.left: parent.left
                anchors.right: close.left
                anchors.rightMargin: 6
                height: parent.height
                radius: Theme.radiusTiny + 2
                color: Theme.s2
                border.width: field.activeFocus ? 2 : 1
                border.color: field.activeFocus ? Theme.acc : Theme.out

                Glyph {
                    id: lens
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    fallback: "search"
                    size: 18
                    color: Theme.mut
                }

                TextField {
                    id: field
                    anchors.left: lens.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    background: null
                    padding: 0
                    color: Theme.fg
                    selectionColor: Theme.accC
                    selectedTextColor: Theme.accCFg
                    placeholderText: root.placeholder
                    placeholderTextColor: Theme.mut
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    Accessible.name: root.placeholder

                    onTextChanged: root.go(0)

                    Keys.onDownPressed: root.go(root.index + 1)
                    Keys.onUpPressed: root.go(root.index - 1)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageDown) {
                            root.go(root.index + root.rows);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageUp) {
                            root.go(root.index - root.rows);
                            event.accepted = true;
                        }
                    }
                    Keys.onReturnPressed: root.choose(root.results[root.index])
                    Keys.onEnterPressed: root.choose(root.results[root.index])
                    Keys.onEscapePressed: root.cancelled()
                }
            }

            IconButton {
                id: close
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                glyph: "close"
                iconName: "window-close"
                tooltip: "Cancel"
                color: Theme.mut
                onActivated: root.cancelled()
            }
        }

        ListView {
            id: list
            width: parent.width
            height: root.rows * root.rowHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.results
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                readonly property bool selected: row.index === root.index

                width: list.width - 10
                height: root.rowHeight
                radius: Theme.radiusSmall
                color: row.selected ? Theme.accC : hover.hovered ? Theme.hover : "transparent"

                Accessible.role: Accessible.ListItem
                Accessible.name: String(row.modelData.name ?? "")
                Accessible.selected: row.selected

                PanelIcon {
                    id: icon
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 24
                    iconName: String(row.modelData.icon ?? "")
                }

                Column {
                    anchors.left: icon.right
                    anchors.leftMargin: 12
                    anchors.right: mark.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    PanelText {
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        color: row.selected ? Theme.accCFg : Theme.fg
                        text: String(row.modelData.name ?? row.modelData.id ?? "")
                    }

                    PanelText {
                        width: parent.width
                        visible: text.length > 0
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        color: row.selected ? Theme.accCFg : Theme.mut
                        opacity: row.selected ? 0.8 : 1
                        text: String(row.modelData.genericName || row.modelData.comment || "")
                    }
                }

                Glyph {
                    id: mark
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.currentId.length > 0 && String(row.modelData.id) === root.currentId
                    name: "check"
                    fallback: "dialog-ok"
                    size: 18
                    color: row.selected ? Theme.accCFg : Theme.acc
                }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.choose(row.modelData) }
            }
        }

        PanelText {
            visible: root.results.length === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 12
            color: Theme.mut
            text: "No installed application matches."
        }

        Row {
            spacing: 6

            KeyCap { anchors.verticalCenter: parent.verticalCenter; text: "↑" }
            KeyCap { anchors.verticalCenter: parent.verticalCenter; text: "↓" }
            PanelText { anchors.verticalCenter: parent.verticalCenter; text: "Move"; font.pixelSize: 12; color: Theme.mut }
            PanelText { anchors.verticalCenter: parent.verticalCenter; text: "·"; font.pixelSize: 12; color: Theme.mut }
            KeyCap { anchors.verticalCenter: parent.verticalCenter; text: "↵" }
            PanelText { anchors.verticalCenter: parent.verticalCenter; text: "Choose"; font.pixelSize: 12; color: Theme.mut }
            PanelText { anchors.verticalCenter: parent.verticalCenter; text: "·"; font.pixelSize: 12; color: Theme.mut }
            KeyCap { anchors.verticalCenter: parent.verticalCenter; text: "esc" }
            PanelText { anchors.verticalCenter: parent.verticalCenter; text: "Cancel"; font.pixelSize: 12; color: Theme.mut }
        }
    }
}
