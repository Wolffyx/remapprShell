pragma ComponentBehavior: Bound

// What a right click on a task button offers: Windows' jump list, built from
// what a Linux application actually declares.
//
// The application's own desktop actions come first -- Chrome's "New Incognito
// Window", Konsole's "Open New Tab" -- then the application itself (a new
// instance), pinning, and closing. Nothing here acts: it says what was chosen,
// and the widget does it.

import QtQuick
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

    width: 262
    spacing: 0

    MenuTitle {
        width: menu.width
        text: menu.item?.appName ?? ""
    }

    Repeater {
        model: Array.from(menu.entry?.actions ?? [])

        MenuRow {
            required property var modelData
            width: menu.width
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
        width: menu.width
        text: menu.entry?.name ?? ""
        glyph: "add"
        onActivated: menu.launch(null)
    }

    MenuSeparator { visible: !!menu.entry; width: menu.width }

    MenuRow {
        visible: !!menu.entry
        width: menu.width
        text: menu.pinned ? "Unpin from taskbar" : "Pin to taskbar"
        glyph: menu.pinned ? "keep_off" : "push_pin"
        onActivated: menu.togglePin()
    }

    MenuRow {
        visible: menu.count > 0
        width: menu.width
        text: menu.count > 1 ? `Close all ${menu.count} windows` : "Close window"
        glyph: "close"
        danger: true
        onActivated: menu.closeWindows()
    }
}
