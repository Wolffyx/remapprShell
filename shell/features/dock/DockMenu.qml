pragma ComponentBehavior: Bound

// Over the dock: the name of the tile under the pointer, or -- after a right
// click on an application -- its menu: the application's own actions first,
// as its desktop entry declares them (Firefox's "New private window",
// Konsole's "Open new tab"), as the taskbar's menu has them, then keep it in
// the dock or take it out, start another, close its windows. Placed over the
// tile, on the side away from the screen's edge, and kept inside the dock's
// window.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: menu

    required property var dock
    required property var body

    readonly property var item: menu.dock.menuItem
    readonly property bool asMenu: menu.item !== null
    readonly property var named: menu.asMenu ? menu.item : menu.body.hoveredItem
    readonly property int count: (menu.item?.windows ?? []).length
    // The application's own actions -- the first `maxActions`, so a long
    // list still leaves the menu inside the dock's window.
    readonly property int maxActions: 6
    readonly property var actions: menu.asMenu
        ? Array.from(menu.dock.entryOf(menu.item)?.actions ?? []).slice(0, menu.maxActions) : []

    visible: menu.asMenu || (menu.named !== null && !menu.dock.hidden && menu.body.dragging !== true)
    width: menu.asMenu ? 240 : label.implicitWidth + 24
    height: menu.asMenu ? rows.implicitHeight + 12 : label.implicitHeight + 12
    radius: menu.asMenu ? Theme.radius : height / 2
    color: menu.asMenu ? Theme.glass : Theme.s3
    border.width: 1
    border.color: Theme.out

    // Over the tile -- clear of it as it has grown, while the dock magnifies
    // -- clear of the dock, inside the window.
    readonly property real along: menu.body.hoveredCentre
    readonly property real clear: menu.dock.margin + menu.dock.thickness + 8 + (menu.body.hoveredLift ?? 0)
    readonly property real _x: menu.dock.horizontal ? menu.along - menu.width / 2
        : (menu.dock.position === "left" ? menu.clear : menu.dock.width - menu.clear - menu.width)
    readonly property real _y: menu.dock.horizontal ? menu.dock.height - menu.clear - menu.height
                                                    : menu.along - menu.height / 2
    x: Math.max(4, Math.min(menu.dock.width - menu.width - 4, menu._x))
    y: Math.max(4, Math.min(menu.dock.height - menu.height - 4, menu._y))

    // Whether the pointer is on the open menu, which keeps the dock up.
    readonly property bool pointerOn: menu.asMenu && menuHover.hovered

    HoverHandler { id: menuHover }

    PanelText {
        id: label
        visible: !menu.asMenu
        anchors.centerIn: parent
        text: menu.named?.appName ?? ""
        font.pixelSize: 13
    }

    Column {
        id: rows
        visible: menu.asMenu
        x: 6
        y: 6
        width: menu.width - 12

        MenuTitle {
            width: parent.width
            text: menu.item?.appName ?? ""
        }

        Repeater {
            model: menu.actions

            MenuRow {
                required property var modelData
                width: rows.width
                text: modelData.name
                iconName: modelData.icon || (menu.item?.iconName ?? "")
                onActivated: menu.dock.launchAction(menu.item, modelData)
            }
        }

        MenuSeparator {
            visible: menu.actions.length > 0
            width: parent.width
        }

        MenuRow {
            width: parent.width
            visible: (menu.item?.appKey ?? "").length > 0
            glyph: menu.dock.isPinned(menu.item) ? "keep_off" : "keep"
            text: menu.dock.isPinned(menu.item) ? "Remove from the dock" : "Keep in the dock"
            onActivated: menu.dock.togglePin(menu.item)
        }

        MenuRow {
            width: parent.width
            visible: (menu.item?.appKey ?? "").length > 0
            glyph: "add"
            text: menu.count > 0 ? "New window" : "Open"
            onActivated: menu.dock.activate(menu.item, Qt.MiddleButton)
        }

        MenuRow {
            width: parent.width
            visible: menu.count > 0
            glyph: "close"
            danger: true
            text: menu.count === 1 ? "Close the window" : `Close ${menu.count} windows`
            onActivated: menu.dock.closeWindows(menu.item)
        }
    }
}
