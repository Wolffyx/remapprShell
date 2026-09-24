// A raised group of related controls: one step up from the surface it sits
// on, with its contents laid out in a column.

import QtQuick
import qs.domain.theme

Rectangle {
    id: root

    default property alias content: column.data
    property alias spacing: column.spacing
    property real padding: 18

    // What a child of the card has to work with. A Repeater's delegate cannot
    // use `parent.width` for this: its parent is the column, and it is null
    // for the moment between the delegate being created and being reparented,
    // which is a TypeError per row on every page that draws rows in a loop.
    readonly property real contentWidth: root.width - 2 * root.padding

    implicitHeight: column.implicitHeight + 2 * root.padding
    radius: Theme.radiusSmall + 2
    color: Theme.s2

    Column {
        id: column
        x: root.padding
        y: root.padding
        width: root.contentWidth
        spacing: 12
    }
}
