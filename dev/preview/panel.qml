import QtQuick
import qs.domain.theme
import qs.domain.config
import qs.features.panel

Rectangle {
    id: stage
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.dark ? "#20283f" : "#c8d5ef" }
        GradientStop { position: 0.45; color: Theme.dark ? "#2c2b3d" : "#e6dcd2" }
        GradientStop { position: 1; color: Theme.dark ? "#3b3138" : "#f2d7c4" }
    }

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

                QtObject {
                    id: mock
                    property string screenName: "PREVIEW"
                    property string position: "bottom"
                    property bool horizontal: true
                    property int thickness: slot.modelData[1]
                    property var screenObject: null
                    property string style: slot.modelData[0]
                    property int spacing: 6
                    property int iconSize: 19
                    property int edgeGap: style === "full" ? 0 : 14
                    property int extent: thickness + edgeGap
                    property Item openPopout: null
                }

                PanelSurface {
                    anchors.fill: parent
                    bar: mock
                }
            }
        }
    }
}
