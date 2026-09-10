// The Quickshell renderer: one layer-shell panel per screen.
//
// It knows about zones and ordering only through PanelModel, and about widgets
// only through WidgetHost. It never asks what a widget is.

import QtQuick
import Quickshell
import qs.core
import qs.features.panel.model
import qs.domain.theme

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // The `bar` half of the widget contract: what a widget is allowed to know
    // about its host. Kept deliberately small -- a widget that needs more than
    // this is usually reaching for something that belongs in the panel.
    readonly property string screenName: root.modelData.name
    readonly property string position: PanelModel.positionFor(root.screenName)
    readonly property bool horizontal: PanelModel.horizontalFor(root.screenName)
    readonly property int thickness: PanelModel.thicknessFor(root.screenName)
    readonly property var screenObject: root.screen

    // ---- hiding ---------------------------------------------------------
    //
    // The one thing in this project that genuinely belongs to us: layer-shell
    // gives us a surface we can shrink to a sliver and grow back, which no
    // amount of configuring Plasma would provide.
    //
    // Hidden means the surface really is a few pixels tall, not a full-height
    // transparent one moved out of sight -- a transparent surface still eats
    // every click that lands on it, and a panel that swallows clicks along a
    // whole screen edge while claiming to be hidden is worse than one that
    // never hides.
    readonly property bool autoHide: PanelModel.autoHideFor(root.screenName)
    readonly property int revealStrip: 3

    property bool pointerInside: false

    // A popout keeps it out: the panel collapsing while a menu opened from it
    // is still on screen would drag the menu away from what opened it.
    readonly property bool revealed: !root.autoHide || root.pointerInside || root.openPopout !== null

    // Leaving is delayed; arriving is not. A panel that vanished the instant
    // the pointer crossed its edge would flicker on the way to a widget near
    // it.
    readonly property Timer _hideTimer: Timer {
        interval: 400
        onTriggered: root.pointerInside = false
    }

    function setPointerInside(inside) {
        if (inside) {
            root._hideTimer.stop();
            root.pointerInside = true;
        } else {
            root._hideTimer.restart();
        }
    }

    anchors {
        top: root.position !== "bottom"
        bottom: root.position !== "top"
        left: root.position !== "right"
        right: root.position !== "left"
    }

    // Per output, not the global value: a monitor override that changed the
    // widgets' idea of the thickness but not the panel's own size left the
    // widgets drawn against a strip of a different height.
    readonly property int visibleThickness: root.revealed ? root.thickness : root.revealStrip

    implicitHeight: root.horizontal ? root.visibleThickness : 0
    implicitWidth: root.horizontal ? 0 : root.visibleThickness

    Behavior on implicitHeight { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
    Behavior on implicitWidth { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    // Reserve the strip so maximised windows stop at the panel rather than
    // being covered by it -- unless it hides, in which case reserving it would
    // defeat the point.
    exclusiveZone: root.autoHide ? 0 : root.thickness

    color: "transparent"

    // Only while a popout that wants the keyboard is open.
    //
    // It used to be unconditional, which cost a click everywhere else: clicking
    // an on-demand layer surface hands it the keyboard, so a click on the task
    // list activated a window and then immediately took focus back off it, and
    // the window only stayed once you clicked a second time. Nothing was
    // gained in return -- `openPopout` was never assigned, so the key
    // forwarding below never ran either.
    focusable: root.openPopout !== null

    // Set by the slot whose popout wants the keyboard, and cleared when it
    // closes. This is what makes the forwarding below work at all.
    property Item openPopout: null

    Rectangle {
        id: surface

        // Keeps its full thickness even while the window is a sliver, and
        // slides out of view instead of being squashed: anchoring it to the
        // edge away from the screen edge means what stays visible is the
        // panel's own inner edge. Squashing it would re-lay-out every widget
        // twice per reveal, for something nobody sees.
        width: root.horizontal ? parent.width : root.thickness
        height: root.horizontal ? root.thickness : parent.height

        anchors {
            bottom: root.position === "top" ? parent.bottom : undefined
            top: root.position === "bottom" ? parent.top : undefined
            right: root.position === "left" ? parent.right : undefined
            left: root.position === "right" ? parent.left : undefined
        }

        color: PlasmaColors.panelBackground

        // Reveals on the way in, hides a moment after the way out.
        HoverHandler {
            id: panelHover
            onHoveredChanged: root.setPointerInside(panelHover.hovered)
        }

        // Typing while the panel has focus goes to whichever popout is open.
        // The panel receives the click that opens a popout, so this is what
        // makes "click the launcher, then type" work. Keys attaches to an
        // Item, never to a window, so it lives here rather than on the panel.
        focus: true
        Keys.forwardTo: root.openPopout ? [root.openPopout] : []

        // Three zones. Left and right hug their edges; middle is centred on the
        // panel itself, not on the space left over between the other two, so a
        // long window title on the left cannot shove the clock off-centre.
        ZoneRow {
            id: leftZone
            zone: "left"
            bar: root
            screenName: root.modelData.name
            horizontal: root.horizontal
            anchors {
                left: root.horizontal ? parent.left : undefined
                top: root.horizontal ? undefined : parent.top
                margins: 8
                verticalCenter: root.horizontal ? parent.verticalCenter : undefined
                horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter
            }
        }

        ZoneRow {
            id: middleZone
            zone: "middle"
            bar: root
            screenName: root.modelData.name
            horizontal: root.horizontal
            anchors.centerIn: parent
        }

        ZoneRow {
            id: rightZone
            zone: "right"
            bar: root
            screenName: root.modelData.name
            horizontal: root.horizontal
            anchors {
                right: root.horizontal ? parent.right : undefined
                bottom: root.horizontal ? undefined : parent.bottom
                margins: 8
                verticalCenter: root.horizontal ? parent.verticalCenter : undefined
                horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter
            }
        }
    }

    Component.onCompleted: Log.info("panel",
        `up on ${modelData.name} (${modelData.width}x${modelData.height}, ${root.position}, ${root.thickness}px`
        + `${root.autoHide ? ", hidden until pointed at" : ""})`)
}
