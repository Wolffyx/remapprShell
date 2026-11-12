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

import QtQuick
import Quickshell
import qs.domain.theme
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
            body.dock.pointerMoved(hovered);
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

                width: body.dock.horizontal ? tile.span : body.size
                height: body.dock.horizontal ? body.size : tile.span

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

                    TapHandler {
                        enabled: !tile.divider
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onTapped: (point, button) => {
                            body.hover(tile, tile.item);
                            body.dock.activate(tile.item, button);
                        }
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
