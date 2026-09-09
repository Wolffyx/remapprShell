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

Column {
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

    spacing: 4

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

            width: root.width
            height: body.implicitHeight + 12
            radius: 6
            color: PlasmaColors.backgroundAlternate

            Column {
                id: body
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 8

                    PanelIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 20
                        iconName: entryRow.manifest?.icon ?? "preferences-desktop-plasma"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 320

                        PanelText {
                            text: entryRow.manifest?.name ?? entryRow.modelData.id
                            color: entryRow.known ? PlasmaColors.foreground : PlasmaColors.negative
                        }

                        PanelText {
                            font.pixelSize: 11
                            color: entryRow.quarantined ? PlasmaColors.negative : PlasmaColors.foregroundInactive
                            text: entryRow.quarantined ? `Disabled after repeated failures: ${Quarantine.reasonFor(entryRow.modelData.id)}`
                                : !entryRow.known ? "Not installed"
                                : (entryRow.manifest?.description ?? "")
                            width: parent.width
                            elide: Text.ElideRight
                        }
                    }

                    Select {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 110
                        values: root.zones
                        currentIndex: Math.max(0, root.zones.indexOf(entryRow.modelData.zone ?? "left"))
                        onPicked: value => root.updateEntry(entryRow.index, { zone: value })
                    }

                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: entryRow.modelData.enabled !== false
                        onToggled: value => root.updateEntry(entryRow.index, { enabled: value })
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "go-up"
                        onActivated: root.moveEntry(entryRow.index, -1)
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "go-down"
                        onActivated: root.moveEntry(entryRow.index, 1)
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: entryRow.expanded ? "arrow-up" : "configure"
                        visible: Object.keys(entryRow.manifest?.config ?? {}).length > 0
                        onActivated: entryRow.expanded = !entryRow.expanded
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "list-remove"
                        onActivated: root.removeEntry(entryRow.index)
                    }
                }

                // The widget's own settings, from its manifest.
                SchemaRenderer {
                    width: parent.width
                    visible: entryRow.expanded
                    keys: entryRow.manifest?.config ?? ({})
                    prefix: `widgets.${entryRow.modelData.id}.`
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
                        color: PlasmaColors.negative
                        font.pixelSize: 11
                    }

                    PanelText {
                        text: "Enable it again"
                        color: PlasmaColors.accent
                        font.pixelSize: 11
                        TapHandler { onTapped: Quarantine.release(entryRow.modelData.id) }
                    }
                }
            }
        }
    }

    PanelText {
        text: "Available widgets"
        font.pixelSize: 14
        topPadding: 12
    }

    Flow {
        width: root.width
        spacing: 6

        Repeater {
            model: Object.keys(WidgetRegistry.all).filter(
                id => !root.entries.some(e => e.id === id))

            Rectangle {
                id: available

                required property string modelData

                width: label.implicitWidth + 28
                height: 28
                radius: 6
                color: addHover.hovered ? PlasmaColors.hoverBackground : PlasmaColors.backgroundAlternate

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
                        text: WidgetRegistry.manifest(available.modelData)?.name ?? available.modelData
                    }
                }

                HoverHandler { id: addHover }
                TapHandler { onTapped: root.addWidget(available.modelData) }
            }
        }
    }
}
