import QtQuick
import qs.domain.config
import qs.features.panel

Stage {
    id: stage
    orientation: Gradient.Vertical
    middle: false

    Component.onCompleted: ConfigStore.setRuntime("bar.entries", [
        { id: "launcher", zone: "left" }, { id: "search", zone: "left" }, { id: "taskview", zone: "left" },
        { id: "divider", zone: "left" }, { id: "workspaces", zone: "left" },
        { id: "clock", zone: "middle" },
        { id: "tray", zone: "right" }, { id: "divider", zone: "right" }, { id: "network", zone: "right" },
        { id: "volume", zone: "right" }, { id: "notifications", zone: "right" }, { id: "power", zone: "right" }
    ])

    Row {
        x: 20
        spacing: 40
        height: parent.height

        Repeater {
            model: [["left", "full"], ["left", "floating"], ["right", "islands"]]

            Item {
                id: slot
                required property var modelData
                width: mock.extent
                height: stage.height

                MockBar {
                    id: mock
                    position: slot.modelData[0]
                    horizontal: false
                    style: slot.modelData[1]
                }

                PanelSurface {
                    anchors.fill: parent
                    bar: mock
                }
            }
        }
    }
}
