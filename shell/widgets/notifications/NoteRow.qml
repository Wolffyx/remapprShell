pragma ComponentBehavior: Bound

// A notification as a row the pointer can open. The history's entries open
// what they are about, the same as a live popup does -- the file named, or the
// application that sent it -- and are tinted under the pointer while a click
// would do that. What the row shows is written inside it.

import QtQuick
import qs.domain.notifications
import qs.domain.theme

Item {
    id: noteRow

    required property var entry
    // Where the tint's edge sits from the row's: out past it when negative.
    property real tintInset: 0

    readonly property string picture: NotificationWatch.pictureOf(noteRow.entry)
    readonly property bool openable: NotificationWatch.openable(noteRow.entry)
    readonly property bool hovered: rowHover.hovered

    // It has opened what it is about, so the popout can go.
    signal opened

    Rectangle {
        anchors.fill: parent
        anchors.margins: noteRow.tintInset
        radius: Theme.radiusOf(12)
        visible: rowHover.hovered && noteRow.openable
        color: Theme.alpha(Theme.fg, 0.06)
    }

    HoverHandler {
        id: rowHover
        cursorShape: noteRow.openable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: noteRow.openable
        onTapped: {
            NotificationWatch.open(noteRow.entry);
            noteRow.opened();
        }
    }
}
