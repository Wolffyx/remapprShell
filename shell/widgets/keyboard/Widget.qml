pragma ComponentBehavior: Bound

// The keyboard layout.
//
// KWin switches layouts -- its shortcut keeps working whatever draws the
// panel -- and Plasma's indicator for them lives in its system tray, which
// our renderer does not have. This is that indicator: the layout's name,
// a click for the next one, the wheel through them all. Absent with a single
// layout, which is most machines, so it is safe in every preset.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.ui.primitives

BarWidget {
    id: root

    readonly property int size: Math.max(22, Math.round(40 * root.unit))

    present: KeyboardStatus.present
    wantsWheel: true

    tooltip: {
        const current = KeyboardStatus.layout;
        if (!current)
            return "";
        const layouts = KeyboardStatus.layouts;
        const next = layouts[StatusIcons.cycleIndex(KeyboardStatus.current, layouts.length, 1)];
        return next && next !== current ? `${current.long}\nClick for ${next.long}` : current.long;
    }

    implicitWidth: Math.max(root.size, label.implicitWidth + 20)
    implicitHeight: root.size

    // A touchpad reports fractions of a notch; a layout moves only once a
    // whole one has built up, or a light swipe would spin through them all.
    property real _wheel: 0

    function handleWheel(delta) {
        root._wheel += delta;
        const notches = root._wheel > 0 ? Math.floor(root._wheel) : Math.ceil(root._wheel);
        if (notches === 0)
            return;
        root._wheel -= notches;
        // Up is back, as it is for the virtual desktops.
        KeyboardStatus.cycle(-notches);
    }

    function handleActivate(button) {
        if (button === Qt.MiddleButton)
            return;
        KeyboardStatus.next();
    }

    BarButton {
        anchors.fill: parent
        thickness: root.bar?.thickness ?? 40
        hovered: root.hovered
        size: root.size
    }

    PanelText {
        id: label
        anchors.centerIn: parent
        text: KeyboardStatus.label
        font.weight: Font.Medium
        font.pixelSize: 12
    }
}
