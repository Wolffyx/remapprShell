pragma ComponentBehavior: Bound

// The strip you pull the sidebar out by.
//
// KWin's screen edges answer a pointer that merely *reaches* the edge, which
// is how the sidebar was opened before -- and a panel that appears because the
// pointer went to the scrollbar is a panel that opens all day by accident.
// This is the other thing every shell with a sidebar does: a few pixels at the
// very edge that has to be pressed and pulled inwards.
//
// One per screen, so the sidebar comes out of *this* monitor rather than the
// first one. That is the whole reason it exists on every screen rather than
// being a single surface: a layer surface belongs to one output, and the
// output it belongs to is the answer to "which screen did you drag on".
//
// It reserves nothing and takes no keyboard. It does take a press at the very
// edge of the screen -- six pixels of it by default -- which is the cost of a
// drag handle, and `sidebar.handleWidth` is how wide that cost is.
// `sidebar.trigger` turns it off in favour of KWin's edge, or of nothing.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.config
import qs.domain.sidebar.cards
import qs.domain.surfaces
import qs.domain.theme

PanelWindow {
    id: handle

    required property var modelData
    screen: handle.modelData

    readonly property bool leftEdge: Cards.onLeft(ConfigStore.value("sidebar.position", "right"))
    readonly property int strip: Math.max(2, Number(ConfigStore.value("sidebar.handleWidth", 6)))

    // How far it has to be pulled before the sidebar comes out. Far enough
    // that a click at the edge is not a drag, short enough that the gesture
    // feels answered rather than resisted.
    readonly property int threshold: 28

    anchors {
        top: true
        bottom: true
        left: handle.leftEdge
        right: !handle.leftEdge
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: `${Branding.slug}-sidebar-handle`
    color: "transparent"

    implicitWidth: handle.strip

    // Nothing to grab while the sidebar is already out: the sidebar's own
    // close button and Escape put it away, and a handle under it would take
    // the press meant for the card.
    visible: !Surfaces.sidebar

    // A hairline that says there is something here, brighter under the
    // pointer. Ten per cent of an accent is not decoration -- an invisible
    // grab strip is one nobody finds.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: Math.min(180, parent.height * 0.22)
        radius: width / 2
        color: Theme.acc
        opacity: pull.active ? 0.85 : hover.hovered ? 0.55 : 0.18
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    HoverHandler {
        id: hover
        cursorShape: handle.leftEdge ? Qt.SizeHorCursor : Qt.SizeHorCursor
    }

    // Pulled inwards: left edge to the right, right edge to the left. The
    // sidebar opens once, when the drag passes the threshold -- not on
    // release, so it comes out under the finger rather than after it.
    DragHandler {
        id: pull

        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        property bool opened: false

        onActiveChanged: if (!active) pull.opened = false

        onTranslationChanged: {
            if (pull.opened || !pull.active)
                return;
            const pulled = handle.leftEdge ? translation.x : -translation.x;
            if (pulled < handle.threshold)
                return;
            pull.opened = true;
            Surfaces.toggleSidebar(handle.screen?.name ?? "");
        }
    }
}
