pragma ComponentBehavior: Bound

// The dock itself: the glass, and the tiles on it in a row (or a column, on
// a side). A tile is an application's icon at the dock's size with a dot
// under it while it has windows -- the accent on the one in front, the
// warning colour while one asks for attention -- or the start button, a
// place, or the divider before the places. What a click does is the dock's
// (Dock.activate); this draws, and says which tile the pointer is on and
// where the pointer is.
//
// While the dock magnifies, each tile is `dock.scales[i]` times as long along
// the dock and its face -- the icon and what takes the pointer -- grows out
// of the glass, away from the edge; the glass keeps its height.
//
// With `dock.rearrange`, an application's tile can be dragged along the
// dock: the tiles it passes step aside, and on release the dock writes the
// new order (Dock.moveTile, DockItems.reorder). Only the run of applications
// moves; the start button, the divider and the places stay where they are.
//
// With `dock.dragToRemove`, a tile kept in the dock can be carried off it,
// away from the edge: past its own size and a quarter it fades and shows a
// minus, and let go there it is taken out (Dock.removeTile). Brought back
// before that, it is a drag along the dock again.

import QtQuick
import Quickshell
import qs.domain.dock
import qs.domain.theme
import qs.ui.controls
import qs.ui.primitives

Rectangle {
    id: body

    required property var dock

    // The tile under the pointer, and its centre along the dock in the
    // dock window's coordinates -- for the name shown over it, and the menu.
    property var hoveredItem: null
    property Item hoveredTile: null
    property real hoveredCentre: body.centreOf(body.hoveredTile)
    // How far the hovered tile has grown out of the glass.
    readonly property real hoveredLift: body.hoveredTile ? (body.hoveredTile.grow - 1) * body.size : 0

    // Whether the pointer is on the dock -- or in the room its tiles grow
    // into -- and where, in the window's coordinates.
    readonly property bool pointerOn: pointerHover.hovered
    readonly property point pointer: pointerHover.hovered ? pointerHover.point.scenePosition : Qt.point(NaN, NaN)

    readonly property int size: body.dock.size
    readonly property var scales: body.dock.scales ?? []
    readonly property int dividerLength: body.dock.dividerLength ?? 9

    // A tile held and dragged, and where it would land: the applications are
    // one size, so the drop is a whole number of steps along the dock.
    readonly property bool dragging: reorder.dragIndex >= 0
    readonly property var dropRange: DockItems.dropRange(body.dock.items)
    readonly property ReorderState reorder: ReorderState {
        rowHeight: body.size + body.dock.gap
        minIndex: body.dropRange[0]
        maxIndex: body.dropRange[1]
        onDropped: (from, to) => body.dock.moveTile(from, to)
    }

    // How far the held tile has been carried away from the edge, and whether
    // that is far enough for it to go when it is let go.
    property real away: 0
    readonly property bool pullingOff: body.dragging && DockItems.pulledOff(body.away, body.size)

    function canRearrange() {
        return body.dock.rearrange === true;
    }

    function canRemove(item) {
        return body.dock.dragToRemove === true && body.dock.isPinned(item) === true;
    }

    // The held tile has moved `along` the dock and `away` from the edge.
    // Pulled off, it keeps its place in the row and passes no one.
    function track(item, index, along, away) {
        body.away = body.canRemove(item) ? Math.max(0, away) : 0;
        if (body.pullingOff || !body.canRearrange()) {
            body.reorder.dropIndex = body.reorder.dragIndex;
            return;
        }
        body.reorder.track(index, along);
    }

    function release(item) {
        const off = body.pullingOff;
        if (off)
            body.reorder.dropIndex = body.reorder.dragIndex;
        body.reorder.end();
        body.away = 0;
        if (off)
            body.dock.removeTile(item);
    }

    width: body.dock.horizontal ? tiles.implicitWidth + 2 * body.dock.pad : body.dock.thickness
    height: body.dock.horizontal ? body.dock.thickness : tiles.implicitHeight + 2 * body.dock.pad
    radius: Math.round(body.size * 0.375)
    color: Theme.glass
    border.width: 1
    border.color: Theme.out

    HoverHandler {
        id: pointerHover
        margin: body.dock.lift ?? 0
        onHoveredChanged: {
            if (!hovered)
                body.hoveredItem = null;
        }
    }

    function itemFor(key) {
        return body.dock.items.find(i => i.key === key) ?? null;
    }

    function centreOf(tile) {
        if (!tile)
            return 0;
        return body.dock.horizontal ? body.x + tiles.x + tile.x + tile.width / 2
                                    : body.y + tiles.y + tile.y + tile.height / 2;
    }

    function hover(tile, item) {
        body.hoveredItem = item;
        body.hoveredTile = tile;
    }

    Grid {
        id: tiles
        anchors.centerIn: parent
        columns: body.dock.horizontal ? Math.max(1, body.dock.items.length) : 1
        spacing: body.dock.gap
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            // Over the keys, as the taskbar does: the items are made afresh
            // whenever any window changes, and a tile should outlive that.
            model: ScriptModel { values: body.dock.items.map(i => i.key) }

            Item {
                id: tile

                required property string modelData
                required property int index
                readonly property var item: body.itemFor(tile.modelData)
                readonly property bool divider: tile.item?.kind === "divider"
                readonly property bool running: (tile.item?.windows ?? []).length > 0
                readonly property real grow: body.scales[tile.index] ?? 1
                // Along the dock at rest, and grown.
                readonly property real span: (tile.divider ? body.dividerLength : body.size) * tile.grow
                // Held: follows the pointer. Passed by the held one: a step aside.
                readonly property bool held: body.reorder.dragIndex === tile.index
                readonly property real offset: tile.held ? (body.canRearrange() ? drag.along : 0)
                                                         : body.reorder.shift(tile.index)
                // Carried away from the edge: up, or out from a side.
                readonly property real lifted: tile.held ? body.away : 0
                readonly property bool leaving: tile.held && body.pullingOff

                width: body.dock.horizontal ? tile.span : body.size
                height: body.dock.horizontal ? body.size : tile.span
                z: tile.held ? 1 : 0
                transform: Translate {
                    x: body.dock.horizontal ? tile.offset : (body.dock.position === "left" ? tile.lifted : -tile.lifted)
                    y: body.dock.horizontal ? -tile.lifted : tile.offset
                }

                Rectangle {
                    visible: tile.divider
                    anchors.centerIn: parent
                    width: body.dock.horizontal ? 1 : Math.round(body.size * 0.8)
                    height: body.dock.horizontal ? Math.round(body.size * 0.8) : 1
                    color: Theme.out
                }

                // The icon and what takes the pointer, grown out of the glass:
                // up from the bottom, out from a side.
                Item {
                    id: face
                    visible: !tile.divider
                    opacity: tile.leaving ? 0.55 : 1
                    width: body.size * tile.grow
                    height: width
                    x: body.dock.position === "right" ? body.size - face.width : 0
                    y: body.dock.horizontal ? body.size - face.height : 0

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(face.width * 0.25)
                        color: hover.hovered ? Theme.hover : "transparent"
                    }

                    PanelIcon {
                        anchors.centerIn: parent
                        implicitSize: Math.round(face.width * 0.84)
                        iconName: tile.item?.iconName ?? ""
                        iconFile: tile.item?.iconFile ?? ""
                    }

                    HoverHandler {
                        id: hover
                        enabled: !tile.divider
                        onHoveredChanged: {
                            if (hovered)
                                body.hover(tile, tile.item);
                        }
                    }

                    DragHandler {
                        id: drag
                        readonly property bool removable: body.canRemove(tile.item)
                        readonly property real along: body.dock.horizontal ? drag.activeTranslation.x : drag.activeTranslation.y
                        readonly property real away: DockItems.awayFromEdge(body.dock.position, drag.activeTranslation)
                        enabled: DockItems.draggable(tile.item) && (body.canRearrange() || drag.removable)
                        target: null
                        acceptedButtons: Qt.LeftButton
                        // Along the dock always; across it only for a tile
                        // that can be carried off.
                        xAxis.enabled: body.dock.horizontal || drag.removable
                        yAxis.enabled: !body.dock.horizontal || drag.removable
                        cursorShape: Qt.ClosedHandCursor

                        onActiveChanged: {
                            if (drag.active)
                                body.reorder.begin(tile.index);
                            else
                                body.release(tile.item);
                        }

                        onActiveTranslationChanged: {
                            if (drag.active)
                                body.track(tile.item, tile.index, drag.along, drag.away);
                        }
                    }

                    TapHandler {
                        enabled: !tile.divider
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onTapped: (point, button) => {
                            body.hover(tile, tile.item);
                            body.dock.activate(tile.item, button);
                        }
                    }
                }

                // Pulled far enough off to go: a minus on its corner.
                Rectangle {
                    visible: tile.leaving
                    width: 20
                    height: 20
                    radius: 10
                    x: tile.width - width / 2 - 4
                    y: -height / 2 + 4
                    color: Theme.error

                    Glyph {
                        anchors.centerIn: parent
                        name: "remove"
                        fallback: "list-remove"
                        size: 16
                        color: Theme.errorFg
                    }
                }

                // Running: a dot on the dock's inner side of the tile.
                Rectangle {
                    visible: tile.running
                    width: tile.item?.active ? 10 : 4
                    height: 4
                    radius: 2
                    color: tile.item?.attention ? Theme.warning : (tile.item?.active ? Theme.acc : Theme.fg)
                    x: body.dock.horizontal ? (tile.width - width) / 2
                                            : (body.dock.position === "left" ? -body.dock.pad + 2 : tile.width + body.dock.pad - 6)
                    y: body.dock.horizontal ? tile.height + Math.round(body.dock.pad / 2) - 2 : (tile.height - height) / 2
                    rotation: body.dock.horizontal ? 0 : 90
                }
            }
        }
    }
}
