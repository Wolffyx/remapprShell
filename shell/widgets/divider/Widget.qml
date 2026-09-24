// A thin line between groups of widgets. Across the panel, whichever way the
// panel runs; takes no input.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

BarWidget {
    id: root

    readonly property int length: Math.max(14, Math.round(26 * root.unit))

    implicitWidth: root.barVertical ? root.length : 9
    implicitHeight: root.barVertical ? 9 : root.length

    Rectangle {
        anchors.centerIn: parent
        width: root.barVertical ? root.length : 1
        height: root.barVertical ? 1 : root.length
        color: Theme.out
    }
}
