pragma ComponentBehavior: Bound

// The sidebar's card for the machine. Folded, the processor and the memory;
// open, the rest. The numbers are read only while the sidebar is open (see
// Sidebar.qml).

import QtQuick
import qs.domain.session
import qs.domain.system
import qs.domain.system.stats
import qs.domain.theme
import qs.ui.primitives

SidebarCard {
    cardId: "machine"
    title: "Machine"
    glyph: "memory"

    // One number, as a line of text over a bar.
    component Meter: Column {
        id: meter
        property string label: ""
        property string value: ""
        property real fraction: 0
        width: parent ? parent.width : 0
        spacing: 6

        Item {
            width: parent.width
            height: 16
            PanelText { text: meter.label; font.pixelSize: 12; color: Theme.mut }
            PanelText { anchors.right: parent.right; text: meter.value; font.pixelSize: 12; color: Theme.mut }
        }

        Rectangle {
            width: parent.width
            height: 5
            radius: 2.5
            color: Theme.alpha(Theme.fg, 0.12)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, meter.fraction))
                height: parent.height
                radius: parent.radius
                color: Theme.acc
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }
    }

    content: [
        Meter {
            label: SystemStats.cpuTemp > 0 ? `CPU · ${SystemStats.cpuTemp} °C` : "CPU"
            value: `${Math.round(SystemStats.cpu * 100)}%`
            fraction: SystemStats.cpu
        },
        Meter {
            label: "Memory"
            value: `${Stats.bytes(SystemStats.memUsed)} / ${Stats.bytes(SystemStats.memTotal)}`
            fraction: SystemStats.memTotal > 0 ? SystemStats.memUsed / SystemStats.memTotal : 0
        }
    ]

    extra: Column {
        spacing: 12

        Meter {
            visible: SystemStats.gpu >= 0
            label: SystemStats.gpuTemp > 0 ? `GPU · ${SystemStats.gpuTemp} °C` : "GPU"
            value: `${Math.round(Math.max(0, SystemStats.gpu) * 100)}%`
            fraction: Math.max(0, SystemStats.gpu)
        }

        Meter {
            label: "Network"
            value: `${Stats.bytes(SystemStats.netRate)}/s`
            // A gigabit's worth is the whole bar.
            fraction: SystemStats.netRate / (125 * 1024 * 1024)
        }

        PanelText {
            width: parent.width
            text: Session.uptime.length > 0 ? `Up ${Session.uptime}` : ""
            font.pixelSize: 11
            color: Theme.mut
        }
    }
}
