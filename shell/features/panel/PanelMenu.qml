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
import Quickshell.Io
import qs.core
import qs.domain.theme
import qs.domain.windows
import qs.ui.primitives

EdgeWindow {
    id: menu

    // Where along the panel the click was, so the menu opens under the
    // pointer rather than in the middle of the screen.
    property real at: 0

    // The system monitor, if this machine has one installed. Plasma's own
    // first, then KDE's older one: a row that would open nothing is left off
    // rather than shown and refusing.
    readonly property var monitorEntry: WindowsService.entryById("org.kde.plasma.systemmonitor")
        ?? WindowsService.entryById("org.kde.ksysguard")

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
                text: "System monitor"
                glyph: "monitoring"
                onActivated: {
                    WindowsService.launch(String(menu.monitorEntry?.id ?? ""), null);
                    menu.chosen();
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
    function run(args): void {
        proc.running = false;
        proc.command = [Branding.ctlBin].concat(args);
        proc.running = true;
        menu.chosen();
    }

    readonly property Process _proc: Process {
        id: proc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0)
                Log.warn("panel", `panel menu: ${text.trim().split("\n").pop()}`)
        }
    }
}
