pragma ComponentBehavior: Bound

// What a right click on a task button offers: Windows' jump list, built from
// what a Linux application actually declares.
//
// The application's own desktop actions come first -- Chrome's "New Incognito
// Window", Konsole's "Open New Tab" -- then the application itself (a new
// instance), pinning, and closing. Nothing here acts: it says what was chosen,
// and the widget does it.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Column {
    id: menu

    // The task item, the application's desktop entry (null for a window no
    // installed application matched), and whether it is pinned.
    required property var item
    required property var entry
    required property bool pinned

    // `action` is one of the entry's actions, or null for the application.
    signal launch(var action)
    signal togglePin
    signal closeWindows

    readonly property int count: menu.item?.windows?.length ?? 0

    width: 260
    spacing: 2

    component MenuRow: Rectangle {
        id: row

        property string text: ""
        property string iconName: ""
        signal activated

        width: parent ? parent.width : 260
        height: 28
        radius: 5
        color: rowHover.hovered ? Theme.hoverBackground : "transparent"

        Row {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            PanelIcon {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                iconName: row.iconName
                opacity: row.iconName.length > 0 ? 1 : 0
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                width: row.width - 40
                text: row.text
                elide: Text.ElideRight
                font.pixelSize: 12
            }
        }

        HoverHandler { id: rowHover }
        TapHandler { onTapped: row.activated() }
    }

    component Separator: Rectangle {
        width: parent ? parent.width : 260
        height: 1
        color: Theme.alpha(Theme.foreground, 0.12)
    }

    PanelText {
        x: 8
        width: menu.width - 16
        text: menu.item?.appName ?? ""
        elide: Text.ElideRight
        color: Theme.foregroundInactive
        font.pixelSize: 11
        font.bold: true
        bottomPadding: 2
    }

    Repeater {
        model: Array.from(menu.entry?.actions ?? [])

        MenuRow {
            required property var modelData
            text: modelData.name
            iconName: modelData.icon || (menu.entry?.icon ?? "")
            onActivated: menu.launch(modelData)
        }
    }

    // A new instance, named as the application -- "Dolphin" -- the way
    // Windows' jump list names it, since not every application opens a
    // second window rather than raising the first.
    MenuRow {
        visible: !!menu.entry
        text: menu.entry?.name ?? ""
        iconName: menu.entry?.icon ?? ""
        onActivated: menu.launch(null)
    }

    Separator { visible: !!menu.entry }

    MenuRow {
        visible: !!menu.entry
        text: menu.pinned ? "Unpin from taskbar" : "Pin to taskbar"
        iconName: menu.pinned ? "window-unpin" : "window-pin"
        onActivated: menu.togglePin()
    }

    MenuRow {
        visible: menu.count > 0
        text: menu.count > 1 ? `Close all ${menu.count} windows` : "Close window"
        iconName: "window-close"
        onActivated: menu.closeWindows()
    }
}
