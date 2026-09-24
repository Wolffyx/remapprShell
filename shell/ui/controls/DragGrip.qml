// The handle a row is dragged by, for a list kept in a ReorderState.
//
// It moves nothing itself: it tells the state where the row is going, and
// the row reads `translation` to follow the pointer while it is the one
// held. Disabled, it cannot be picked up and is drawn faint -- the tray's
// last icon on the panel, which may not leave it.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

Item {
    id: root

    required property ReorderState reorder
    required property int index

    // How far the pointer has taken the row since the drag began.
    readonly property real translation: handler.activeTranslation.y

    implicitWidth: 22
    implicitHeight: 22

    Glyph {
        anchors.centerIn: parent
        name: "drag_indicator"
        fallback: "transform-move"
        size: 18
        color: Theme.mut
        opacity: !root.enabled ? 0.25 : root.reorder.dragIndex === root.index ? 1 : 0.7
    }

    DragHandler {
        id: handler
        target: null            // the row moves itself
        xAxis.enabled: false
        cursorShape: Qt.ClosedHandCursor

        onActiveChanged: {
            if (handler.active)
                root.reorder.begin(root.index);
            else
                root.reorder.end();
        }

        onTranslationChanged: {
            if (handler.active)
                root.reorder.track(root.index, handler.activeTranslation.y);
        }
    }
}
