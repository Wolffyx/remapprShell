// One position in a zone: the widget, plus the interaction it asked for.
//
// The panel reads capabilities and calls the matching function. It never asks
// what a widget *is*. That is the difference between a panel that can host
// widgets it has never heard of and one that needs editing for each new type.

import QtQuick
import Quickshell
import qs.ui.primitives
import qs.domain.theme

Item {
    id: root

    required property var entry
    required property var bar
    required property string screenName
    required property var widgetConfig

    readonly property BarWidget widget: host.item as BarWidget
    readonly property bool wantsHover: root.widget?.wantsHover ?? false
    readonly property bool wantsWheel: root.widget?.wantsWheel ?? false
    readonly property bool interactive: root.wantsHover || root.wantsWheel || !!root.widget?.popout

    implicitWidth: host.implicitWidth
    implicitHeight: host.implicitHeight

    WidgetHost {
        id: host
        anchors.fill: parent
        entry: root.entry
        bar: root.bar
        screenName: root.screenName
        widgetConfig: root.widgetConfig
    }

    MouseArea {
        anchors.fill: parent

        // A widget that asked for nothing stays click-through, so a decorative
        // widget cannot accidentally swallow input meant for the panel.
        enabled: root.interactive
        visible: root.interactive
        hoverEnabled: root.wantsHover
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPositionChanged: event => {
            if (root.wantsHover)
                root.widget.handleHover(root.bar.horizontal ? event.x : event.y, root.bar.horizontal);
        }

        onExited: if (root.wantsHover) root.widget.dismissPopout()

        onWheel: event => {
            if (!root.wantsWheel) {
                event.accepted = false;
                return;
            }
            // Normalise to steps: touchpads report pixel deltas, wheels report
            // 120ths of a degree. Widgets should not have to know which.
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y / 120
                                                   : event.pixelDelta.y / 50;
            root.widget.handleWheel(delta);
        }

        onClicked: event => root.widget?.handleActivate(event.button)
    }

    // A widget that declares a popout gets a window for it, positioned under
    // itself. The widget supplies the contents and never touches placement --
    // which is what lets a plugin have a popout without knowing where on the
    // panel it sits or which edge the panel is on.
    //
    // A layer surface rather than an xdg popup, deliberately. Wayland only
    // grants a popup the keyboard if its parent surface has already received
    // input, so a popup-based launcher can be focused by clicking the button
    // but never by a keybinding or `rmpr launcher` -- the panel has had no
    // input in that case, and the grab is refused. A layer surface asks for
    // keyboard focus directly and works either way.
    PanelWindow {
        id: popout

        readonly property bool wanted: !!root.widget?.popout && !!root.widget?.popoutVisible
        readonly property Item popoutContent: content.item as Item
        readonly property bool atTop: root.bar?.position === "top"

        // Where this slot sits along the panel, in screen coordinates. The
        // panel spans the screen, so a position within it is a position on it.
        readonly property real slotX: root.mapToItem(null, 0, 0).x

        visible: popout.wanted
        screen: root.bar?.screenObject ?? null

        anchors {
            top: popout.atTop
            bottom: !popout.atTop
            left: true
        }

        // Kept on screen: a popout under a button near the right edge would
        // otherwise run off it.
        //
        // The linter cannot resolve the grouped `margins` property on a panel
        // window and warns about it; the property is real and works at
        // runtime. (Note for the next person: a comment whose first word is
        // the linter's own name is parsed as a directive to it.)
        margins.left: Math.max(0, Math.min(popout.slotX, (popout.screen?.width ?? 0) - popout.implicitWidth - 8))
        margins.top: popout.atTop ? (root.bar?.thickness ?? 0) + 4 : 0
        margins.bottom: popout.atTop ? 0 : (root.bar?.thickness ?? 0) + 4

        // The panel already reserves its strip; this must not reserve another.
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: root.widget?.popoutGrabsFocus ?? false

        color: "transparent"

        implicitWidth: popout.popoutContent?.implicitWidth ?? 1
        implicitHeight: popout.popoutContent?.implicitHeight ?? 1

        // Tell the panel, so it takes the keyboard for as long as this is open
        // and forwards what it receives here. A popout that only displays
        // something does not ask, and the panel stays out of the way.
        onWantedChanged: {
            if (!root.bar)
                return;
            if (popout.wanted && (root.widget?.popoutGrabsFocus ?? false))
                root.bar.openPopout = popout.popoutContent;
            else if (root.bar.openPopout === popout.popoutContent)
                root.bar.openPopout = null;
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: PlasmaColors.background
            border.width: 1
            border.color: PlasmaColors.alpha(PlasmaColors.foreground, 0.15)

            // Quickshell 0.3.1 exposes no layer-shell keyboard-focus mode, so
            // `focusable` is on-demand: Wayland grants the keyboard only once
            // the surface is clicked. Clicking into the popout therefore
            // works; a popout opened from a keybinding has nothing to click,
            // which is why the panel forwards its keys here too.
            focus: true
            Keys.forwardTo: popout.popoutContent ? [popout.popoutContent] : []

            Loader {
                id: content
                anchors.fill: parent
                anchors.margins: 8
                // Built only while shown: a popout that is never opened should
                // cost nothing, and one that is closed should not keep state.
                active: popout.wanted
                sourceComponent: root.widget?.popout ?? null
            }
        }
    }
}
