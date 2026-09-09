// A switch.

import QtQuick
import qs.domain.theme

Item {
    id: root

    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 38
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? PlasmaColors.accent
                            : PlasmaColors.alpha(PlasmaColors.foreground, 0.2)
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            width: parent.height - 4
            height: width
            radius: width / 2
            y: 2
            x: root.checked ? parent.width - width - 2 : 2
            color: root.checked ? PlasmaColors.background : PlasmaColors.foreground
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }

    TapHandler { onTapped: root.toggled(!root.checked) }
}
