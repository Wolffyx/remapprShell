// The line between groups of menu rows.

import QtQuick
import qs.domain.theme

Item {
    implicitWidth: 120
    implicitHeight: 13

    Rectangle {
        x: 10
        width: parent.width - 20
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Theme.out
    }
}
