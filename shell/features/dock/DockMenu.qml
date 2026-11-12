pragma ComponentBehavior: Bound

// Over the dock: the name of the tile under the pointer, or -- after a right
// click on an application -- its menu: keep it in the dock or take it out,
// start another, close its windows. Placed over the tile, on the side away
// from the screen's edge, and kept inside the dock's window.

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

    HoverHandler {
        onHoveredChanged: {
            if (menu.asMenu)
                menu.dock.pointerMoved(hovered);
        }
    }

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
