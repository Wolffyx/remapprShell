pragma ComponentBehavior: Bound

// The window for the built-in launcher.
//
// Only the built-in provider gets one. Every other provider is its own process
// or plasmashell's, and those position and dismiss themselves -- chasing an
// external window's geometry on Wayland is not something to attempt.

import QtQuick
import qs.core
import QtQuick.Controls
import qs.domain.launcher
import qs.domain.launcher.providers
import qs.domain.theme
import qs.ui.primitives

// The contents of the launcher popout. The window around it is the panel's --
// see WidgetSlot -- so this is a plain Item and knows nothing about anchoring.
Item {
    id: root

    readonly property BuiltinProvider provider: LauncherService.builtin

    implicitWidth: 380
    implicitHeight: layout.implicitHeight + 16

    // The window this lives in has to accept focus before anything inside it
    // can hold it, and this component is built before the surface is mapped --
    // so asking for focus in Component.onCompleted alone is too early and the
    // request is silently dropped. callLater runs after the window exists.
    focus: true
    Component.onCompleted: Qt.callLater(() => search.forceActiveFocus())

    // Typing anywhere in the popout goes to the search field, so a click on a
    // result row does not leave the keyboard pointing at nothing.
    Keys.forwardTo: [search]

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.background
        border.width: 1
        border.color: Theme.alpha(Theme.foreground, 0.15)

        Column {
            id: layout
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            TextField {
                id: search
                focus: true
                width: parent.width
                placeholderText: "Search applications"
                color: Theme.foreground
                text: root.provider.query

                background: Rectangle {
                    radius: 5
                    color: Theme.backgroundAlternate
                }

                onTextChanged: {
                    root.provider.query = text;
                    root.provider.selectedIndex = 0;
                }

                // Verifiable without typing: opened from a keybinding with
                // nothing clicked, this says whether the keyboard arrived.
                onActiveFocusChanged: Log.info("launcher",
                    search.activeFocus ? "search has the keyboard" : "search lost the keyboard")

                Keys.onDownPressed: root.provider.moveSelection(1)
                Keys.onUpPressed: root.provider.moveSelection(-1)
                Keys.onReturnPressed: root.provider.activateSelected()
                Keys.onEnterPressed: root.provider.activateSelected()
                Keys.onEscapePressed: root.provider.close()
            }

            Repeater {
                model: root.provider.results

                Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    width: layout.width
                    height: 34
                    radius: 5
                    color: row.index === root.provider.selectedIndex
                        ? Theme.alpha(Theme.accent, 0.25)
                        : (rowHover.hovered ? Theme.hoverBackground : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        spacing: 8

                        PanelIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 22
                            iconName: row.modelData.icon ?? ""
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            PanelText { text: row.modelData.name ?? "" }

                            PanelText {
                                visible: (row.modelData.genericName ?? "").length > 0
                                text: row.modelData.genericName ?? ""
                                font.pixelSize: 11
                                color: Theme.foregroundInactive
                            }
                        }
                    }

                    HoverHandler {
                        id: rowHover
                        onHoveredChanged: if (hovered) root.provider.selectedIndex = row.index
                    }

                    TapHandler {
                        onTapped: {
                            root.provider.selectedIndex = row.index;
                            root.provider.activateSelected();
                        }
                    }
                }
            }

            PanelText {
                visible: root.provider.results.length === 0
                text: root.provider.query.length > 0 ? "No matches" : "No applications found"
                color: Theme.foregroundInactive
            }
        }
    }
}
