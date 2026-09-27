// The body of a panel widget's popout: a column, in an Item that says how
// wide it wants to be.
//
// The popout's window is sized from its contents' implicit size on the frame
// it is shown, and a bare Column has none until its children have been laid
// out: opened cold, the notification centre drew its card a few pixels square
// -- a round blob with nothing in it -- and only the second opening looked
// right. Every popout wrapped its Column in an Item for that reason, ten times
// over. This is that Item: the width is the widget's to state, as
// `implicitWidth`, and the height is the column's.
//
//   PopoutColumn {
//       id: body
//       implicitWidth: 300
//       spacing: 8
//       ...
//   }
//
// What is written inside goes into the column, so `parent.width` there is
// the popout's width, as is `body.width` in a delegate.

import QtQuick

Item {
    id: root

    // The popout's contents, top to bottom.
    default property alias content: column.data
    property alias spacing: column.spacing

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
    }
}
