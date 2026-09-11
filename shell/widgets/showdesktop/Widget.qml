// The thin strip at the far end of the panel that shows the desktop.
//
// KWin already implements showing the desktop, so this only asks it to. The
// widget is the affordance, not the mechanism -- and whether the desktop is
// showing is read back from KWin, so Meta+D or a hot corner counts too.
//
// Peek, when turned on, is Windows' "peek at the desktop": rest the pointer on
// the strip and the windows get out of the way until it leaves. A click while
// peeking keeps the desktop, as it does there. It is KWin's own show-desktop
// underneath, so the windows move away rather than turning to glass.

import QtQuick
import qs.ui.primitives
import qs.domain.theme
import qs.domain.desktops

BarWidget {
    id: root

    readonly property int stripWidth: root.widgetConfig?.width ?? 8
    readonly property bool peekEnabled: root.widgetConfig?.peek ?? false
    readonly property int peekDelay: root.widgetConfig?.peekDelay ?? 500

    readonly property bool showing: Desktops.showingDesktop

    // True while the desktop is shown only because the pointer rests on the
    // strip. The pointer leaving puts the windows back; anything else that
    // brings them back -- activating a window -- ends the peek with it.
    property bool peeking: false

    wantsHover: true

    tooltip: root.peeking ? "Click to keep the desktop"
           : root.showing ? "Bring the windows back"
           : "Show the desktop"

    implicitWidth: root.bar?.horizontal ? root.stripWidth : root.bar?.thickness ?? root.stripWidth
    implicitHeight: root.bar?.horizontal ? (root.bar?.thickness ?? 24) : root.stripWidth

    function handleActivate(button) {
        if (root.peeking) {
            root.peeking = false;
            return;
        }
        Desktops.showDesktop(!root.showing);
    }

    onHoveredChanged: {
        if (root.hovered) {
            if (root.peekEnabled && !root.showing)
                peekTimer.restart();
            return;
        }
        peekTimer.stop();
        if (root.peeking) {
            root.peeking = false;
            Desktops.showDesktop(false);
        }
    }

    onShowingChanged: if (!root.showing) root.peeking = false

    Timer {
        id: peekTimer
        interval: root.peekDelay
        onTriggered: {
            if (!root.hovered || root.showing)
                return;
            root.peeking = true;
            Desktops.showDesktop(true);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.hovered || root.showing ? PlasmaColors.hoverBackground : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        // A hairline so the strip is discoverable rather than an invisible
        // region the user has to know about.
        Rectangle {
            anchors.centerIn: parent
            width: root.bar?.horizontal ? 1 : parent.width * 0.5
            height: root.bar?.horizontal ? parent.height * 0.5 : 1
            color: PlasmaColors.alpha(PlasmaColors.foreground, 0.3)
        }
    }
}
