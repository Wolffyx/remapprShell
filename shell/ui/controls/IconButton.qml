// A small icon button.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

Item {
    id: root

    property string iconName: ""
    property string tooltip: ""
    signal activated

    implicitWidth: 26
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: 5
        color: hover.hovered ? PlasmaColors.hoverBackground : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        PanelIcon {
            anchors.centerIn: parent
            implicitSize: 15
            iconName: root.iconName
        }

        HoverHandler { id: hover }
        TapHandler { onTapped: root.activated() }
    }
}
