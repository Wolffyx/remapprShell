// The screen's corner beyond the panel's last widget, caught for that widget.
//
// A pointer thrown at a screen corner stops exactly there, which makes the
// corner the easiest target on the screen and the reason show-desktop lives in
// one. The panel's last widget never reached it: a full strip keeps its
// padding beyond the widget, and a floating bar stops short of the corner and
// stands off the edge. So the corner was padding that answered nothing, or the
// window underneath -- the show-desktop strip "did not work" while Meta+D did
// (issue #15), because nobody aims at an eight-pixel strip twelve pixels from
// a corner they can throw the pointer into.
//
// A widget claims its corner with `ownsCorner`. While it is the last thing at
// that end of the bar (ZoneRow.cornerSlot), this covers everything from it to
// the corner and hands the press, the click, the wheel and the hover to its
// slot, so the corner is the widget: tooltip, peek and right-click menu
// included. PanelSurface adds it to the panel's input region too, or a
// floating bar would let the click through to the window beneath.

import QtQuick

Item {
    id: root

    // The WidgetSlot that owns this corner, or null for none.
    property var slot: null

    visible: root.slot !== null

    // The slot told it is hovered, so it can be told it is not -- whichever
    // slot that turns out to be by then.
    property var _told: null

    function _tell(hovered) {
        const next = hovered ? root.slot : null;
        if (root._told === next)
            return;
        if (root._told)
            root._told.cornerHovered = false;
        root._told = next;
        if (next)
            next.cornerHovered = true;
    }

    onSlotChanged: root._tell(area.containsMouse)

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: root.slot !== null
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onContainsMouseChanged: {
            root._tell(area.containsMouse);
            if (!area.containsMouse && root.slot)
                root.slot.pointerExited();
        }
        onPressed: root.slot.pointerPressed()
        onWheel: event => root.slot.pointerWheel(event)
        onClicked: event => root.slot.pointerClicked(event.button, area, event.x, event.y)
    }
}
