pragma ComponentBehavior: Bound

// Composition root. It wires features together and owns no logic of its own --
// every behaviour lives in a layer below (see scripts/lint-layers.sh).

import Quickshell
import QtQuick
import qs.core

ShellRoot {
    id: root

    // One panel per screen. Variants rebuilds the set on monitor hotplug, so
    // nothing here has to watch for display changes.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData
            screen: modelData

            // Phase 0: a fixed strip on the bottom edge. Position, size and
            // contents all become config-driven in Phase 1.
            anchors {
                left: true
                right: true
                bottom: true
            }

            implicitHeight: 40

            // Reserve the strip so maximised windows stop above it. Without
            // this the panel would overlap windows rather than displace them.
            exclusiveZone: implicitHeight

            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.55)

                Text {
                    anchors.centerIn: parent
                    color: "white"
                    font.pixelSize: 13
                    text: `${Branding.displayName} ${Branding.version} — ${panel.modelData.name}`
                }
            }

            Component.onCompleted: Log.info("panel", `up on ${modelData.name} (${modelData.width}x${modelData.height})`)
        }
    }

    Component.onCompleted: Log.info("shell", `${Branding.displayName} ${Branding.version} started`)
}
