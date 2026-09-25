import QtQuick
import qs.domain.config
import qs.features.panel

Stage {
    id: stage

    Component.onCompleted: ConfigStore.setRuntime("bar.entries", [
        { id: "launcher", zone: "left" }, { id: "search", zone: "left" }, { id: "taskview", zone: "left" },
        { id: "divider", zone: "left" }, { id: "workspaces", zone: "left" },
        { id: "tasks", zone: "middle" },
        { id: "tray", zone: "right" }, { id: "divider", zone: "right" }, { id: "network", zone: "right" },
        { id: "bluetooth", zone: "right" }, { id: "volume", zone: "right" }, { id: "battery", zone: "right" },
        { id: "clock", zone: "right" }, { id: "notifications", zone: "right" }, { id: "power", zone: "right" }
    ])

    Column {
        y: 24
        spacing: 28
        width: parent.width

        Repeater {
            model: [["full", 64], ["floating", 64], ["islands", 64], ["full", 44], ["floating", 44]]

            Item {
                id: slot
                required property var modelData
                width: stage.width
                height: mock.extent

                MockBar {
                    id: mock
                    thickness: slot.modelData[1]
                    style: slot.modelData[0]
                }

                PanelSurface {
                    anchors.fill: parent
                    bar: mock
                }
            }
        }
    }
}
