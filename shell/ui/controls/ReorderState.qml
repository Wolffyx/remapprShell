// A list reordered by dragging: which row is held, where it would land, and
// how far every other row has to move to open the gap.
//
// The list is not rewritten while the pointer moves. Dragging is a question
// until it is released, and writing on every frame would put a configuration
// write -- and whatever rebuilds from it -- behind each pixel. The rows move
// under the pointer, and `dropped` says once, on release, where the held one
// went.
//
// A plain object the page owns, beside a DragGrip on each row:
//
//     readonly property ReorderState reorder: ReorderState {
//         rowHeight: 38
//         maxIndex: root.rows.length - 1
//         onDropped: (from, to) => root.moveRow(from, to)
//     }
//
// and each row is offset by reorder.shift(index), or by its grip's own
// translation while it is the one being dragged.

import QtQuick

QtObject {
    id: root

    // How far one row is from the next. Rows of one height can say it; rows
    // that grow keep it up to date themselves.
    property real rowHeight: 0

    // Where a row may be dropped, inclusive. A list that begins with a
    // heading starts at 1.
    property int minIndex: 0
    property int maxIndex: 0

    property int dragIndex: -1
    property int dropIndex: -1

    // A drag ended somewhere other than where it began.
    signal dropped(int from, int to)

    function begin(index) {
        root.dragIndex = index;
        root.dropIndex = index;
    }

    // The held row has moved `translation` pixels from where it started.
    function track(index, translation) {
        const steps = Math.round(translation / root.rowHeight);
        root.dropIndex = Math.max(root.minIndex, Math.min(root.maxIndex, index + steps));
    }

    function end() {
        const from = root.dragIndex;
        const to = root.dropIndex;
        root.dragIndex = -1;
        root.dropIndex = -1;
        if (from >= 0 && to >= 0 && from !== to)
            root.dropped(from, to);
    }

    // How far a row that is not held sits from its place: the rows the held
    // one has passed shift by one to open a gap.
    function shift(index) {
        if (root.dragIndex < 0 || index === root.dragIndex)
            return 0;
        if (root.dragIndex < root.dropIndex && index > root.dragIndex && index <= root.dropIndex)
            return -root.rowHeight;
        if (root.dragIndex > root.dropIndex && index >= root.dropIndex && index < root.dragIndex)
            return root.rowHeight;
        return 0;
    }
}
