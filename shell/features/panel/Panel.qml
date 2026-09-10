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

    anchors {
        top: root.position !== "bottom"
        bottom: root.position !== "top"
        left: root.position !== "right"
        right: root.position !== "left"
    }

    implicitHeight: root.horizontal ? PanelModel.thickness : 0
    implicitWidth: root.horizontal ? 0 : PanelModel.thickness

    // Reserve the strip so maximised windows stop at the panel rather than
    // being covered by it.
    exclusiveZone: PanelModel.thickness

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
        anchors.fill: parent
        color: PlasmaColors.panelBackground

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

    Component.onCompleted: Log.info("panel", `up on ${modelData.name} (${modelData.width}x${modelData.height}, ${root.position})`)
}
