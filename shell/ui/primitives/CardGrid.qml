// Cards side by side where there is room for two, and stacked where there is
// not.
//
// A settings page in this design is a set of named cards rather than one
// column of full-width rows: at the window's usual size a card the whole width
// of the page puts its label at one end of a long empty line and its control at
// the other, which is the look this replaces.
//
// A Flow rather than a grid because the cards differ in height and the last
// row is usually short. Each card asks for `cellWidth`; nothing here reaches
// into a child to size it, so a card that wants the full width can still say
// so.

import QtQuick

Flow {
    id: root

    // Narrower than this and two columns are worse than one: the controls are
    // pushed against the labels and every description wraps to four lines.
    property int minimumCardWidth: 360

    // How many cards there are. `visibleChildren` counts a Repeater as one of
    // them -- it is an Item, even though it draws nothing and the Flow steps
    // over it -- so a page that builds its cards from a model says how many it
    // built.
    property int count: root.visibleChildren.length

    // One card alone across the whole page reads as a mistake rather than as a
    // column, so a page with one card gets the width it would have had before
    // there was a grid.
    readonly property int columns: Math.max(1, Math.min(2,
        Math.floor((root.width + root.spacing) / (root.minimumCardWidth + root.spacing)),
        root.count))

    readonly property real cellWidth: (root.width - (root.columns - 1) * root.spacing) / root.columns

    spacing: 16
}
