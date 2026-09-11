pragma ComponentBehavior: Bound

// An application's own tray menu, drawn by us.
//
// The obvious route is `SystemTrayItem.display()`, which hands the menu to Qt.
// It does not work here, and the reason is worth writing down: a platform menu
// is a QWidget popup that must be an xdg_popup parented to a window that has
// already received input. Our panel is a layer-shell surface, so Qt refuses it
// twice over -- "Cannot attach popup ... as the popup is not an xdg_popup",
// and a grabbing-popup warning before that. It also needs the whole shell
// started in QApplication mode for a single menu.
//
// So the entries are read with QsMenuOpener -- which is a plain model of text,
// icons, check states and submenus -- and drawn like anything else we draw.
// The application supplies the content and we supply the look, which is the
// same division as everywhere else in this project.
//
// Submenus open in place rather than in a second window. A menu that has to
// spawn windows to show "All (29) >" is a menu that can fail to spawn one.

import QtQuick
import Quickshell
import qs.domain.theme
import qs.ui.primitives

Column {
    id: root

    // The item's `menu` handle. Assigning it starts a DBus round trip, so the
    // entries arrive a moment after this is built -- which is why nothing here
    // assumes a first frame with content in it.
    property var handle: null

    // Emitted once the user has chosen something, so the popout can close.
    signal chosen

    readonly property int rowHeight: 26
    readonly property int indent: 16

    spacing: 1

    QsMenuOpener {
        id: opener
        menu: root.handle
    }

    readonly property var entries: opener.children?.values ?? []

    PanelText {
        visible: root.entries.length === 0
        text: "…"
        color: Theme.foregroundInactive
        leftPadding: 8
        topPadding: 4
        bottomPadding: 4
    }

    Repeater {
        model: root.entries

        // One entry, and its children when it is a submenu the user opened.
        Column {
            id: entry

            required property var modelData

            readonly property bool separator: entry.modelData?.isSeparator ?? false
            property bool expanded: false

            spacing: 1

            // A separator is a line, not a row you can hit.
            Rectangle {
                visible: entry.separator
                width: Math.max(120, root.width)
                height: 1
                color: Theme.alpha(Theme.foreground, 0.15)
            }

            Item {
                visible: !entry.separator
                implicitWidth: line.implicitWidth + 24
                implicitHeight: root.rowHeight
                width: Math.max(implicitWidth, root.width)

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    radius: 4
                    color: (rowHover.hovered && (entry.modelData?.enabled ?? false))
                        ? Theme.hoverBackground : "transparent"
                }

                Row {
                    id: line
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Check and radio states are drawn rather than dropped:
                    // an application that shows a setting in its menu is
                    // relying on the tick to say which way it is set.
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 14
                        implicitHeight: 14
                        visible: (entry.modelData?.buttonType ?? QsMenuButtonType.None) !== QsMenuButtonType.None
                              || (entry.modelData?.icon ?? "").length > 0

                        PanelIcon {
                            anchors.fill: parent
                            visible: (entry.modelData?.icon ?? "").length > 0
                            source: entry.modelData?.icon ?? ""
                        }

                        PanelIcon {
                            anchors.fill: parent
                            visible: (entry.modelData?.icon ?? "").length === 0
                                  && (entry.modelData?.checkState ?? Qt.Unchecked) !== Qt.Unchecked
                            iconName: (entry.modelData?.buttonType ?? 0) === QsMenuButtonType.RadioButton
                                ? "media-record" : "checkbox"
                        }
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData?.text ?? ""
                        opacity: (entry.modelData?.enabled ?? false) ? 1 : 0.45
                        font.pixelSize: 12
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entry.modelData?.hasChildren ?? false
                        text: entry.expanded ? "⌄" : "›"
                        color: Theme.foregroundInactive
                        font.pixelSize: 12
                    }
                }

                HoverHandler { id: rowHover }

                TapHandler {
                    enabled: entry.modelData?.enabled ?? false
                    onTapped: {
                        if (entry.modelData?.hasChildren ?? false) {
                            entry.expanded = !entry.expanded;
                            return;
                        }
                        // `triggered` is how an entry is activated; the
                        // application does whatever it means by it.
                        entry.modelData.triggered();
                        root.chosen();
                    }
                }
            }

            // The submenu, in place. Built only while open, so a menu with
            // four submenus does not fetch four menus over DBus to show one.
            //
            // Loaded by file name rather than by type: QML refuses to let a
            // component instantiate itself ("TrayMenu is instantiated
            // recursively") and a menu of menus is recursive by nature. A URL
            // is resolved at runtime, which is what breaks the cycle.
            Loader {
                id: submenu
                active: entry.expanded && (entry.modelData?.hasChildren ?? false)
                visible: active

                onActiveChanged: {
                    if (active)
                        submenu.setSource("TrayMenu.qml", { handle: entry.modelData, x: root.indent });
                    else
                        submenu.source = "";
                }

                Connections {
                    target: submenu.item
                    ignoreUnknownSignals: true
                    function onChosen() { root.chosen(); }
                }
            }
        }
    }
}
