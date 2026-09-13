import QtQuick
import qs.domain.theme
import qs.domain.config
import qs.features.panel

Rectangle {
    id: stage
    gradient: Gradient {
        GradientStop { position: 0; color: Theme.dark ? "#20283f" : "#c8d5ef" }
        GradientStop { position: 1; color: Theme.dark ? "#3b3138" : "#f2d7c4" }
    }

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

                QtObject {
                    id: mock
                    property string screenName: "PREVIEW"
                    property string position: slot.modelData[0]
                    property bool horizontal: false
                    property int thickness: 64
                    property var screenObject: null
                    property string style: slot.modelData[1]
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
