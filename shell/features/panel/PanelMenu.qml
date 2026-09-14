pragma ComponentBehavior: Bound

// What a right click on the panel itself offers.
//
// Every other desktop has one: a click on empty panel opens a short menu
// about the panel and the session rather than about any one widget. Without
// it, a right click between the buttons did nothing at all, which reads as the
// panel being dead rather than as a menu nobody wrote.
//
// It is deliberately short, and everything on it leads somewhere that can do
// more: the settings window for the shell and its widgets, Plasma's own system
// monitor for what is running. Anything that acts on this shell goes through
// the CLI, which is the one implementation of each of those actions.

import QtQuick
import qs.core
import qs.domain.panel.menu
import qs.domain.theme
import qs.domain.windows
import qs.ui.primitives

EdgeWindow {
    id: menu

    // Where along the panel the click was, so the menu opens under the
    // pointer rather than in the middle of the screen.
    property real at: 0

    // Which system monitor, and what else is on the menu, are settings now --
    // PanelMenuModel answers both, and the settings page edits the same keys.
    // A row that would open nothing is left off rather than shown and refusing.
    readonly property var monitorEntry: PanelMenuModel.monitorEntry
    readonly property var customEntries: PanelMenuModel.entries

    signal chosen

    label: "panel menu"
    centre: menu.at
    align: "centre"
    gap: 10
    shadowMargin: Math.ceil(menu.shadowBlur + menu.shadowDrop)

    implicitWidth: 244 + menu.padH
    implicitHeight: rows.implicitHeight + 16 + menu.padV

    readonly property real shadowBlur: Theme.shadows ? 26 : 0
    readonly property real shadowDrop: Theme.shadows ? 8 : 0

    Rectangle {
        id: card

        x: menu.padLeft
        y: menu.padTop
        width: parent.width - menu.padH
        height: parent.height - menu.padV
        radius: Math.min(Theme.radius, width / 2, height / 2)
        color: Theme.glass
        border.width: 1
        border.color: Theme.out

        Column {
            id: rows

            x: 0
            y: 8
            width: parent.width

            MenuTitle { width: parent.width; text: Branding.displayName }

            MenuRow {
                width: parent.width
                text: "Shell settings"
                glyph: "tune"
                onActivated: menu.run(["settings"])
            }

            MenuRow {
                width: parent.width
                text: "Widgets on the panel"
                glyph: "widgets"
                onActivated: menu.run(["settings", "widgets"])
            }

            MenuRow {
                width: parent.width
                visible: !!menu.monitorEntry
                // Named as the application, so the row says which one it is
                // about to open rather than what kind of thing it is.
                text: menu.monitorEntry?.name || "System monitor"
                glyph: "monitoring"
                onActivated: {
                    WindowsService.launch(String(menu.monitorEntry?.id ?? ""), null);
                    menu.chosen();
                }
            }

            MenuSeparator {
                width: parent.width
                visible: menu.customEntries.length > 0
            }

            // Whatever has been added in Settings -> Taskbar. These run a
            // command line rather than reaching into the shell, so they go
            // through PanelMenuModel rather than through `rmpr`.
            Repeater {
                model: menu.customEntries

                MenuRow {
                    required property var modelData
                    width: rows.width
                    text: modelData.label
                    glyph: modelData.glyph
                    onActivated: {
                        PanelMenuModel.runEntry(modelData.command);
                        menu.chosen();
                    }
                }
            }

            MenuSeparator { width: parent.width }

            MenuRow {
                width: parent.width
                text: "Reload the shell"
                glyph: "refresh"
                onActivated: menu.run(["reload"])
            }
        }
    }

    // Nothing here acts on the shell directly: `rmpr` is the one
    // implementation of each of these, and a second one in QML is what drifts.
    //
    // The process that runs it belongs to PanelMenuModel rather than to this
    // window -- see runCtl there for why a menu cannot own the process it
    // starts as it closes.
    function run(args): void {
        PanelMenuModel.runCtl(args);
        menu.chosen();
    }
}
