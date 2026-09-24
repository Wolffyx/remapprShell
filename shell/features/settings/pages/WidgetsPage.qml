pragma ComponentBehavior: Bound

// Which widgets are on the panel, in which zone, and their own settings.
//
// A widget's settings come from its manifest, rendered by the same
// SchemaRenderer as everything else -- so a third-party widget gets a real
// settings page without this file knowing anything about it.

import QtQuick
import qs.domain.config
import qs.domain.widgets
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls
import qs.features.settings

CardGrid {
    id: root

    readonly property var entries: ConfigStore.value("bar.entries", [])
    readonly property var zones: ["left", "middle", "right"]

    // Writes the entry list back in display order. The order within a zone is
    // significant, so it must be written as shown rather than rebuilt from a
    // set -- otherwise reordering silently does nothing.
    function updateEntry(index, changes) {
        const next = JSON.parse(JSON.stringify(root.entries));
        if (!next[index])
            return;
        Object.assign(next[index], changes);
        ConfigStore.set("bar.entries", next);
    }

    // Reordering by dragging.
    //
    // The list is not rewritten while the pointer moves: dragging is a
    // question until it is released, and writing on every frame would put a
    // configuration write and a panel rebuild behind each pixel. The rows move
    // under the pointer, and one write happens on release.
    property int dragIndex: -1        // the row being dragged
    property int dropIndex: -1        // where it would land
    property real rowHeight: 56

    function commitDrag() {
        const from = root.dragIndex;
        const to = root.dropIndex;
        root.dragIndex = -1;
        root.dropIndex = -1;
        if (from < 0 || to < 0 || from === to)
            return;
        root.moveEntry(from, to - from);
    }

    // Where a row sits while a drag is in progress: the dragged one follows the
    // pointer, and the rows it has passed shift by one to open a gap.
    function dragShift(index) {
        if (root.dragIndex < 0 || index === root.dragIndex)
            return 0;
        if (root.dragIndex < root.dropIndex && index > root.dragIndex && index <= root.dropIndex)
            return -root.rowHeight;
        if (root.dragIndex > root.dropIndex && index >= root.dropIndex && index < root.dragIndex)
            return root.rowHeight;
        return 0;
    }

    function moveEntry(index, delta) {
        const next = JSON.parse(JSON.stringify(root.entries));
        const target = index + delta;
        if (target < 0 || target >= next.length)
            return;
        const [item] = next.splice(index, 1);
        next.splice(target, 0, item);
        ConfigStore.set("bar.entries", next);
    }

    function addWidget(id) {
        const next = JSON.parse(JSON.stringify(root.entries));
        next.push({ id: id, zone: "right", enabled: true });
        ConfigStore.set("bar.entries", next);
    }

    function removeEntry(index) {
        const next = JSON.parse(JSON.stringify(root.entries));
        next.splice(index, 1);
        ConfigStore.set("bar.entries", next);
    }

    count: 2

    // A widget's row carries its name, its zone, a switch and five buttons, so
    // both cards here take the whole row rather than half of it.
    Card {
        id: onPanel

        width: root.width
        spacing: 6

        SectionLabel { text: "On the panel" }

        Repeater {
            model: root.entries

            Rectangle {
                id: entryRow

                required property var modelData
                required property int index

                readonly property var manifest: WidgetRegistry.manifest(entryRow.modelData.id)
                readonly property bool known: entryRow.manifest !== null
                readonly property bool quarantined: Quarantine.isQuarantined(entryRow.modelData.id)
                property bool expanded: false

                width: onPanel.width - 2 * onPanel.padding
                height: body.implicitHeight + 12
                radius: Theme.radiusOf(12)
                color: Theme.s1

                readonly property bool dragging: root.dragIndex === entryRow.index

                // Above the others while it moves, so it is not drawn behind the
                // rows it is passing.
                z: entryRow.dragging ? 2 : 1
                opacity: entryRow.dragging ? 0.85 : 1

                onHeightChanged: if (entryRow.height > 0) root.rowHeight = entryRow.height + 4

                HoverHandler { id: rowHover }

                transform: Translate {
                    y: entryRow.dragging ? dragHandler.activeTranslation.y : root.dragShift(entryRow.index)

                    // Only the rows making way animate; the dragged one must track
                    // the pointer exactly or it feels like it is lagging behind.
                    Behavior on y {
                        enabled: !entryRow.dragging
                        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                    }
                }

                Column {
                    id: body
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Row {
                        id: line

                        // Everything on this line that is not the name, so the
                        // name gets the rest. It was a written-down 320, which
                        // was already short by the time the row gained a
                        // drag grip -- and short only while the pointer was on
                        // the row, because the four buttons appear on hover:
                        // the row overflowed its card and the last button was
                        // drawn outside the window.
                        readonly property real fixed: 20 + zone.width + onOff.width
                            + grip.width + up.width + down.width
                            + configure.width + remove.width + 8 * spacing

                        width: parent.width
                        spacing: 8

                        PanelIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 20
                            iconName: entryRow.manifest?.icon ?? "preferences-desktop-plasma"
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(80, parent.width - line.fixed)

                            PanelText {
                                text: entryRow.manifest?.name ?? entryRow.modelData.id
                                font.pixelSize: 14
                                color: entryRow.known ? Theme.fg : Theme.error
                            }

                            PanelText {
                                font.pixelSize: 12
                                color: entryRow.quarantined ? Theme.error : Theme.mut
                                text: entryRow.quarantined ? `Disabled after repeated failures: ${Quarantine.reasonFor(entryRow.modelData.id)}`
                                    : !entryRow.known ? "Not installed"
                                    : (entryRow.manifest?.description ?? "")
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }

                        Select {
                            id: zone

                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 110
                            values: root.zones
                            labels: root.zones.map(z => z.charAt(0).toUpperCase() + z.slice(1))
                            currentIndex: Math.max(0, root.zones.indexOf(entryRow.modelData.zone ?? "left"))
                            onPicked: value => root.updateEntry(entryRow.index, { zone: value })
                        }

                        Toggle {
                            id: onOff

                            anchors.verticalCenter: parent.verticalCenter
                            checked: entryRow.modelData.enabled !== false
                            onToggled: value => root.updateEntry(entryRow.index, { enabled: value })
                        }

                        // Drag to reorder. The arrows it replaces are still here
                        // for anyone who cannot drag -- shown when the row is
                        // under the pointer, so they are available without being
                        // permanent furniture.
                        Item {
                            id: grip

                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 22
                            implicitHeight: 22

                            Glyph {
                                anchors.centerIn: parent
                                name: "drag_indicator"
                                fallback: "transform-move"
                                size: 18
                                color: Theme.mut
                                opacity: entryRow.dragging ? 1 : 0.7
                            }

                            DragHandler {
                                id: dragHandler
                                target: null            // the row moves itself
                                xAxis.enabled: false
                                cursorShape: Qt.ClosedHandCursor

                                onActiveChanged: {
                                    if (active) {
                                        root.dragIndex = entryRow.index;
                                        root.dropIndex = entryRow.index;
                                    } else {
                                        root.commitDrag();
                                    }
                                }

                                onTranslationChanged: {
                                    if (!dragHandler.active)
                                        return;
                                    const steps = Math.round(dragHandler.activeTranslation.y / root.rowHeight);
                                    const target = entryRow.index + steps;
                                    root.dropIndex = Math.max(0, Math.min(root.entries.length - 1, target));
                                }
                            }
                        }

                        IconButton {
                            id: up

                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "arrow_upward"
                            iconName: "go-up"
                            opacity: rowHover.hovered ? 1 : 0
                            enabled: rowHover.hovered
                            onActivated: root.moveEntry(entryRow.index, -1)
                        }

                        IconButton {
                            id: down

                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "arrow_downward"
                            iconName: "go-down"
                            opacity: rowHover.hovered ? 1 : 0
                            enabled: rowHover.hovered
                            onActivated: root.moveEntry(entryRow.index, 1)
                        }

                        IconButton {
                            id: configure

                            anchors.verticalCenter: parent.verticalCenter
                            glyph: entryRow.expanded ? "expand_less" : "tune"
                            iconName: entryRow.expanded ? "arrow-up" : "configure"
                            tooltip: entryRow.expanded ? "Hide its settings" : "Its settings"
                            opacity: Object.keys(entryRow.manifest?.config ?? {}).length > 0 ? 1 : 0
                            enabled: Object.keys(entryRow.manifest?.config ?? {}).length > 0
                            onActivated: entryRow.expanded = !entryRow.expanded
                        }

                        IconButton {
                            id: remove

                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "close"
                            iconName: "list-remove"
                            tooltip: "Take it off the panel"
                            onActivated: root.removeEntry(entryRow.index)
                        }
                    }

                    // The widget's own settings, from its manifest -- built
                    // when the row is opened, not for every row on the page
                    // and then hidden.
                    Loader {
                        width: parent.width
                        visible: entryRow.expanded
                        active: entryRow.expanded
                        sourceComponent: SchemaRenderer {
                            title: "Settings"
                            keys: entryRow.manifest?.config ?? ({})
                            prefix: `widgets.${entryRow.modelData.id}.`
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        visible: entryRow.quarantined
                        color: "transparent"
                    }

                    Row {
                        visible: entryRow.quarantined
                        spacing: 8

                        PanelText {
                            text: "This widget was disabled automatically."
                            color: Theme.error
                            font.pixelSize: 12
                        }

                        PanelText {
                            text: "Enable it again"
                            color: Theme.acc
                            font.pixelSize: 12
                            TapHandler { onTapped: Quarantine.release(entryRow.modelData.id) }
                        }
                    }
                }
            }
        }
    }

    Card {
        id: availableCard

        width: root.width
        spacing: 10

        SectionLabel { text: "Available widgets" }

        Flow {
            width: availableCard.width - 2 * availableCard.padding
            spacing: 6

            Repeater {
                model: Object.keys(WidgetRegistry.all).filter(
                    id => !root.entries.some(e => e.id === id))

                Rectangle {
                    id: available

                    required property string modelData

                    width: label.implicitWidth + 30
                    height: 30
                    radius: Theme.radiusOf(10)
                    color: addHover.hovered ? Theme.hover : Theme.s1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        PanelIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 14
                            iconName: "list-add"
                        }

                        PanelText {
                            id: label
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 13
                            text: WidgetRegistry.manifest(available.modelData)?.name ?? available.modelData
                        }
                    }

                    HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.addWidget(available.modelData) }
                }
            }
        }

        PanelText {
            visible: Object.keys(WidgetRegistry.all).every(id => root.entries.some(e => e.id === id))
            text: "Every installed widget is already on the panel."
            font.pixelSize: 13
            color: Theme.mut
        }
    }
}
