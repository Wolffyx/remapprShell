// A thin line between groups of widgets. Across the panel, whichever way the
// panel runs; takes no input.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

BarWidget {
    id: root

    readonly property bool vertical: !(root.bar?.horizontal ?? true)
    readonly property int length: Math.max(14, Math.round(26 * root.unit))

    implicitWidth: root.vertical ? root.length : 9
    implicitHeight: root.vertical ? 9 : root.length

    Rectangle {
        anchors.centerIn: parent
        width: root.vertical ? root.length : 1
        height: root.vertical ? 1 : root.length
        color: Theme.out
    }
}
