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

    // Over the top-level menu: the application's icon and name. A submenu,
    // opened in place, has neither.
    property string title: ""
    property string iconSource: ""

    // Emitted once the user has chosen something, so the popout can close.
    signal chosen

    readonly property int indent: 16

    spacing: 0
    width: Math.max(236, implicitWidth)

    QsMenuOpener {
        id: opener
        menu: root.handle
    }

    readonly property var entries: opener.children?.values ?? []

    Item {
        visible: root.title.length > 0
        width: root.width
        height: visible ? 44 : 0

        Row {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            PanelIcon {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 18
                iconFile: root.iconSource
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.width - 50)
                elide: Text.ElideRight
                text: root.title
                font.weight: Font.Medium
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            x: 8
            width: parent.width - 16
            height: 1
            color: Theme.out
        }
    }

    Item { visible: root.title.length > 0; width: 1; height: 6 }

    PanelText {
        visible: root.entries.length === 0
        text: "…"
        color: Theme.mut
        leftPadding: 12
        topPadding: 6
        bottomPadding: 6
    }

    Repeater {
        model: root.entries

        // One entry, and its children when it is a submenu the user opened.
        Column {
            id: entry

            required property var modelData

            readonly property bool separator: entry.modelData?.isSeparator ?? false
            readonly property bool submenu: entry.modelData?.hasChildren ?? false
            readonly property int buttonType: entry.modelData?.buttonType ?? QsMenuButtonType.None
            property bool expanded: false

            spacing: 0

            // A separator is a line, not a row you can hit.
            MenuSeparator {
                visible: entry.separator
                width: root.width
            }

            // Check and radio states are drawn rather than dropped: an
            // application that shows a setting in its menu is relying on the
            // tick to say which way it is set.
            MenuRow {
                visible: !entry.separator
                width: root.width
                enabled: entry.modelData?.enabled ?? false
                text: entry.modelData?.text ?? ""
                iconSource: entry.modelData?.icon ?? ""
                check: entry.buttonType === QsMenuButtonType.RadioButton ? "radio"
                     : entry.buttonType === QsMenuButtonType.CheckBox ? "check" : ""
                checked: (entry.modelData?.checkState ?? Qt.Unchecked) !== Qt.Unchecked
                trailingGlyph: entry.submenu ? (entry.expanded ? "expand_more" : "chevron_right") : ""

                onActivated: {
                    if (entry.submenu) {
                        entry.expanded = !entry.expanded;
                        return;
                    }
                    // `triggered` is how an entry is activated; the
                    // application does whatever it means by it.
                    entry.modelData.triggered();
                    root.chosen();
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
                active: entry.expanded && entry.submenu
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
