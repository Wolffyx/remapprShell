pragma ComponentBehavior: Bound

// Which tray icons are on the panel.
//
// Three lists, and a row is dragged between them. That is the whole idea: the
// alternative is typing StatusNotifierItem ids into a text field, which is
// what this replaces -- and an id like `org.kde.StatusNotifierItem-5616-1` is
// not something anyone should have to type or recognise.
//
// The three lists are the tray's three states, so what is on screen here is
// exactly what is stored: ids on the panel, ids behind the chevron, ids left
// out. Nothing is inferred.
//
// One rule the page enforces rather than explains: the panel list is never
// emptied. An empty list means "show everything" in the widget -- which is
// what makes a fresh install useful -- so dragging the last icon away would
// silently bring all of them back. The last row simply will not move, and the
// note under the list says so.

import QtQuick
import Quickshell.Services.SystemTray
import qs.domain.config
import qs.domain.tray.layout
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

CardGrid {
    id: root

    readonly property string base: "widgets.tray"

    readonly property var pinned: ConfigStore.value(`${root.base}.pinned`, [])
    readonly property var hiddenIds: ConfigStore.value(`${root.base}.hidden`, [])

    readonly property var items: SystemTray.items?.values ?? []

    function itemFor(id) {
        return root.items.find(i => i && i.id === id) ?? null;
    }

    // A tray item's id is a machine string; its title is what a person would
    // recognise. Neither is reliably present, so this falls back through what
    // there is rather than showing an empty row.
    function labelFor(item, id) {
        if (!item)
            return id;
        return item.tooltipTitle || item.title || item.id;
    }

    // ---- the flat list the page draws and drags -------------------------
    //
    // Headers and rows share one index space and one height, so a drag is the
    // same arithmetic as anywhere else and crossing a header is what moves a
    // row between lists.

    readonly property var sections: [
        { title: "On the panel", note: "Shown in this order." },
        { title: "Behind the chevron", note: "One click away." },
        { title: "Never shown", note: "Left out altogether." }
    ]

    readonly property var rows: {
        // The same split the panel draws from, so this page cannot show one
        // arrangement while the panel draws another.
        const ids = TrayLayout.splitIds(root.items, root.pinned, root.hiddenIds);
        const out = [];

        out.push({ header: true, section: 0 });
        for (const id of ids.shown)
            out.push({ header: false, section: 0, id: id });

        out.push({ header: true, section: 1 });
        for (const id of ids.overflow)
            out.push({ header: false, section: 1, id: id });

        out.push({ header: true, section: 2 });
        for (const id of ids.hidden)
            out.push({ header: false, section: 2, id: id });

        return out;
    }

    readonly property int rowHeight: 38

    // How many are on the panel: the last of them may not leave it.
    readonly property int panelCount: root.rows.filter(r => !r.header && r.section === 0).length

    // A drop lands below the first heading, so nothing is ever put above it.
    readonly property ReorderState reorder: ReorderState {
        rowHeight: root.rowHeight
        minIndex: 1
        maxIndex: root.rows.length - 1
        onDropped: (from, to) => root.moveRow(from, to)
    }

    // Writes all three lists from a flat order. One write, so the panel
    // rebuilds once rather than three times.
    function commit(flat) {
        const onPanel = [];
        const hidden = [];
        let section = -1;
        for (const row of flat) {
            if (row.header) {
                section = row.section;
                continue;
            }
            if (section === 0)
                onPanel.push(row.id);
            else if (section === 2)
                hidden.push(row.id);
            // Section 1 is everything left over, so it is not stored.
        }

        // Refusing to write an empty panel list, for the reason at the top:
        // empty means "everything", so this would undo itself.
        if (onPanel.length === 0)
            return;

        ConfigStore.set(`${root.base}.pinned`, onPanel);
        ConfigStore.set(`${root.base}.hidden`, hidden);
    }

    function moveRow(from, to) {
        if (from === to || from < 0 || to < 0)
            return;
        const flat = root.rows.map(r => Object.assign({}, r));
        const moved = flat.splice(from, 1)[0];
        if (!moved || moved.header)
            return;
        flat.splice(Math.max(1, Math.min(flat.length, to)), 0, moved);
        root.commit(flat);
    }

    count: 2

    // The three lists are dragged between, so this card takes the whole row.
    Card {
        id: lists

        width: root.width
        spacing: 12

        SectionLabel { text: "The three lists" }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            lineHeight: 1.35
            text: root.items.length === 0
                ? "Nothing is in the tray at the moment. Applications appear here as they start."
                : "Drag a row into another list. Icons on the panel keep the order you leave them in."
        }

        Item {
            width: parent.width
            height: root.rows.length * root.rowHeight

            Repeater {
                model: root.rows

                Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool dragging: root.reorder.dragIndex === row.index
                    readonly property bool isLastOnPanel: !row.modelData.header
                        && row.modelData.section === 0 && root.panelCount === 1

                    // Looked up once per row rather than once per line that
                    // shows something of it.
                    readonly property var trayItem: row.modelData.header ? null : root.itemFor(row.modelData.id)
                    readonly property bool running: row.trayItem !== null

                    width: parent.width
                    height: root.rowHeight
                    y: row.index * root.rowHeight
                       + (row.dragging ? grip.translation : root.reorder.shift(row.index))
                    z: row.dragging ? 2 : 1

                    Behavior on y {
                        enabled: !row.dragging
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    // ---- a list heading
                    PanelText {
                        visible: row.modelData.header
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        text: root.sections[row.modelData.section].title
                        font.bold: true
                        font.pixelSize: 12
                    }

                    PanelText {
                        visible: row.modelData.header
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 7
                        text: root.sections[row.modelData.section].note
                        color: Theme.mut
                        font.pixelSize: 11
                    }

                    Rectangle {
                        visible: row.modelData.header
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Theme.out
                    }

                    // ---- an item
                    Rectangle {
                        visible: !row.modelData.header
                        anchors.fill: parent
                        anchors.topMargin: 2
                        anchors.bottomMargin: 2
                        radius: Theme.radiusOf(9)
                        color: row.dragging ? Theme.accC
                             : (rowHover.hovered ? Theme.hover : "transparent")

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            PanelIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 18
                                source: row.trayItem?.icon ?? ""
                                fallbackName: row.modelData.id ?? ""
                                opacity: row.running ? 1 : 0.4
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 18 - grip.width - up.width - down.width - parent.spacing * 4

                                PanelText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: root.labelFor(row.trayItem, row.modelData.id ?? "")
                                    font.pixelSize: 12
                                }

                                // The id is worth showing: it is what the config
                                // holds, and two windows of one application can
                                // share a title but never an id.
                                PanelText {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: row.running
                                        ? (row.modelData.id ?? "")
                                        : `${row.modelData.id ?? ""} -- not running`
                                    color: Theme.mut
                                    font.pixelSize: 11
                                }
                            }

                            // Drag to move between lists. The arrows beside it do
                            // the same thing for anyone who would rather not drag,
                            // and appear only under the pointer.
                            DragGrip {
                                id: grip
                                anchors.verticalCenter: parent.verticalCenter
                                enabled: !row.isLastOnPanel
                                reorder: root.reorder
                                index: row.index
                            }

                            IconButton {
                                id: up
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: "arrow_upward"
                                iconName: "go-up"
                                visible: rowHover.hovered && !row.isLastOnPanel
                                onActivated: root.moveRow(row.index, row.index - 1)
                            }

                            IconButton {
                                id: down
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: "arrow_downward"
                                iconName: "go-down"
                                visible: rowHover.hovered && !row.isLastOnPanel
                                onActivated: root.moveRow(row.index, row.index + 1)
                            }
                        }

                        HoverHandler { id: rowHover }
                    }
                }
            }
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            lineHeight: 1.35
            text: "One icon always stays on the panel: an empty list means 'show everything', so emptying it would bring them all back. An application that is not running keeps its place until you move it."
        }
    }

    Card {
        id: sizeCard

        width: root.cellWidth

        SectionLabel { text: "Icon size" }

        SettingRow {
            width: parent.width
            label: "Icon size"
            overridden: ConfigStore.isOverridden(`${root.base}.iconSize`)
            onResetRequested: ConfigStore.reset(`${root.base}.iconSize`)
            NumberSlider {
                width: parent.width
                from: 12
                to: 48
                stepSize: 2
                value: ConfigStore.value(`${root.base}.iconSize`, 22)
                onMoved: value => ConfigStore.set(`${root.base}.iconSize`, Math.round(value))
            }
        }
    }
}
