// The Quickshell renderer: one layer-shell panel per screen.
//
// It knows about zones and ordering only through PanelModel, and about widgets
// only through WidgetHost. It never asks what a widget is.

import QtQuick
import Quickshell
import qs.core
import qs.features.panel.model

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property string position: PanelModel.position
    readonly property bool horizontal: PanelModel.horizontal

    anchors {
        top: root.position !== "bottom"
        bottom: root.position !== "top"
        left: root.position !== "right"
        right: root.position !== "left"
    }

    implicitHeight: root.horizontal ? PanelModel.thickness : 0
    implicitWidth: root.horizontal ? 0 : PanelModel.thickness

    // Reserve the strip so maximised windows stop at the panel rather than
    // being covered by it.
    exclusiveZone: PanelModel.thickness

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        // Three zones. Left and right hug their edges; middle is centred on the
        // panel itself, not on the space left over between the other two, so a
        // long window title on the left cannot shove the clock off-centre.
        ZoneRow {
            id: leftZone
            zone: "left"
            bar: root
            screenName: root.modelData.name
            horizontal: root.horizontal
            anchors {
                left: root.horizontal ? parent.left : undefined
                top: root.horizontal ? undefined : parent.top
                margins: 8
                verticalCenter: root.horizontal ? parent.verticalCenter : undefined
                horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter
            }
        }

        ZoneRow {
            id: middleZone
            zone: "middle"
            bar: root
            screenName: root.modelData.name
            horizontal: root.horizontal
            anchors.centerIn: parent
        }

        ZoneRow {
            id: rightZone
            zone: "right"
            bar: root
            screenName: root.modelData.name
            horizontal: root.horizontal
            anchors {
                right: root.horizontal ? parent.right : undefined
                bottom: root.horizontal ? undefined : parent.bottom
                margins: 8
                verticalCenter: root.horizontal ? parent.verticalCenter : undefined
                horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter
            }
        }
    }

    Component.onCompleted: Log.info("panel", `up on ${modelData.name} (${modelData.width}x${modelData.height}, ${root.position})`)
}
