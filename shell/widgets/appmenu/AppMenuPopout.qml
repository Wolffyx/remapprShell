pragma ComponentBehavior: Bound

// One of the application's menus, under its title on the panel: its entries
// with their shortcuts, ticks and radio marks, separators where the
// application put them. A submenu opens in place of the menu, with the way
// back as its first row -- a panel popout is one card, and cards beside cards
// would run off the screen's edge.

import QtQuick
import qs.ui.primitives

Column {
    id: pop

    required property var widget

    // The submenus opened on the way down, by id; empty at the top.
    property var trail: []

    readonly property var base: pop.widget.openItem
    readonly property var current: pop.trail.length > 0 ? pop.find(pop.base?.children ?? [], pop.trail[pop.trail.length - 1]) : pop.base
    readonly property var rows: pop.current?.children ?? []

    // Another menu opened from the bar: back to its top.
    onBaseChanged: pop.trail = []

    function find(list, id) {
        for (const item of list ?? []) {
            if (item.id === id)
                return item;
            const inside = pop.find(item.children, id);
            if (inside)
                return inside;
        }
        return null;
    }

    function choose(item) {
        if (!item.submenu) {
            pop.widget.choose(item.id);
            return;
        }
        pop.widget.menu?.aboutToShow(item.id);
        pop.trail = pop.trail.concat([item.id]);
    }

    readonly property var _checks: ({ checkmark: "check", radio: "radio" })

    width: pop.widget.popoutWidth - 2 * pop.widget.popoutPadding
    spacing: 0

    MenuRow {
        width: pop.width
        visible: pop.trail.length > 0
        glyph: "chevron_left"
        text: pop.current?.label ?? ""
        onActivated: pop.trail = pop.trail.slice(0, -1)
    }

    MenuSeparator {
        width: pop.width
        visible: pop.trail.length > 0
    }

    Repeater {
        model: pop.rows

        Item {
            id: entry

            required property var modelData
            readonly property bool separator: entry.modelData.separator === true

            width: pop.width
            height: entry.separator ? sep.implicitHeight : row.implicitHeight

            MenuSeparator {
                id: sep
                width: parent.width
                visible: entry.separator
            }

            MenuRow {
                id: row
                width: parent.width
                visible: !entry.separator
                enabled: entry.modelData.enabled !== false
                text: entry.modelData.label
                iconName: entry.modelData.icon ?? ""
                check: pop._checks[entry.modelData.toggle] ?? ""
                checked: entry.modelData.checked === true
                trailing: entry.modelData.submenu === true ? "" : (entry.modelData.shortcut ?? "")
                trailingGlyph: entry.modelData.submenu === true ? "chevron_right" : ""
                onActivated: pop.choose(entry.modelData)
            }
        }
    }

    PanelText {
        visible: pop.rows.length === 0
        leftPadding: 12
        topPadding: 8
        bottomPadding: 8
        text: "Nothing in this menu"
        opacity: 0.6
    }
}
