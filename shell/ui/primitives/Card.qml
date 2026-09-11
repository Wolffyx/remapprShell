// A raised group of related controls: one step up from the surface it sits
// on, with its contents laid out in a column.

import QtQuick
import qs.domain.theme

Rectangle {
    id: root

    default property alias content: column.data
    property alias spacing: column.spacing
    property real padding: 18

    implicitHeight: column.implicitHeight + 2 * root.padding
    radius: Theme.radiusSmall + 2
    color: Theme.s2

    Column {
        id: column
        x: root.padding
        y: root.padding
        width: root.width - 2 * root.padding
        spacing: 12
    }
}
