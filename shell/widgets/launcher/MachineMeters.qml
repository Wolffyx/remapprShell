pragma ComponentBehavior: Bound

// The machine, on the two-pane start menu's side: a meter each for the
// processor, memory, storage and the graphics card, where it has one.
//
// The numbers are only read while the menu that shows them is open: StartMenu
// asks SystemStats to watch for as long as it is in two panes.

import QtQuick
import qs.domain.system
import qs.domain.system.stats
import qs.domain.theme
import qs.ui.primitives

Item {
    height: meters.implicitHeight + 32

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.out
    }

    Column {
        id: meters
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 13

        Repeater {
            model: [
                { label: SystemStats.cpuTemp > 0 ? `CPU · ${SystemStats.cpuTemp} °C` : "CPU",
                  value: `${Math.round(SystemStats.cpu * 100)}%`, fraction: SystemStats.cpu, shown: true },
                { label: "Memory", value: `${Stats.bytes(SystemStats.memUsed)} / ${Stats.bytes(SystemStats.memTotal)}`,
                  fraction: SystemStats.memTotal > 0 ? SystemStats.memUsed / SystemStats.memTotal : 0, shown: true },
                { label: "Storage", value: `${Stats.bytes(SystemStats.diskFree)} free`,
                  fraction: SystemStats.diskSize > 0 ? 1 - SystemStats.diskFree / SystemStats.diskSize : 0, shown: SystemStats.diskSize > 0 },
                { label: SystemStats.gpuTemp > 0 ? `GPU · ${SystemStats.gpuTemp} °C` : "GPU",
                  value: `${Math.round(Math.max(0, SystemStats.gpu) * 100)}%`, fraction: Math.max(0, SystemStats.gpu), shown: SystemStats.gpu >= 0 }
            ].filter(m => m.shown)

            Column {
                id: meter
                required property var modelData
                width: meters.width
                spacing: 6

                Item {
                    width: parent.width
                    height: 16
                    PanelText { text: meter.modelData.label; font.pixelSize: 12; color: Theme.mut }
                    PanelText { anchors.right: parent.right; text: meter.modelData.value; font.pixelSize: 12; color: Theme.mut }
                }

                Rectangle {
                    width: parent.width
                    height: 5
                    radius: 2.5
                    color: Theme.alpha(Theme.fg, 0.12)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, meter.modelData.fraction))
                        height: parent.height
                        radius: parent.radius
                        color: Theme.acc
                        Behavior on width { NumberAnimation { duration: 400 } }
                    }
                }
            }
        }
    }
}
