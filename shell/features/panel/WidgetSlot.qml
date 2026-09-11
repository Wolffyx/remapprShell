// One position in a zone: the widget, plus the interaction it asked for.
//
// The panel reads capabilities and calls the matching function. It never asks
// what a widget *is*. That is the difference between a panel that can host
// widgets it has never heard of and one that needs editing for each new type.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.ui.primitives
import qs.domain.theme
import qs.features.panel.model

Item {
    id: root

    required property var entry
    required property var bar
    required property string screenName
    required property var widgetConfig

    readonly property BarWidget widget: host.item as BarWidget

    // The length this widget may take along the panel; -1 for no limit. The
    // zone works it out; the widget decides whether it can give way.
    property real room: -1

    Binding {
        target: root.widget
        property: "room"
        value: root.room
        when: root.widget !== null
    }

    // Where along this slot the popout should point, as the widget last asked.
    // A widget with one popout for the whole of itself never sets it and gets
    // the slot's own edge; one with a row of things -- a task list -- names the
    // centre of the thing being hovered, so the popout appears under that
    // rather than under the start of the row.
    property real popoutCentre: 0

    // Closes this slot's popout: another one has opened, or a click landed
    // somewhere else. PanelModel decides when.
    function closePopout() {
        if (root.widget)
            root.widget.popoutVisible = false;
    }

    Connections {
        target: root.widget
        function onRequestPopout(name: string, centre: real): void {
            root.popoutCentre = centre;
        }
    }

    // A widget that takes hover from the panel gets it through the MouseArea
    // below, which then hides the pointer from the widget's own handlers.
    Binding {
        target: root.widget
        property: "hostHovered"
        value: mouse.containsMouse
        when: root.widget !== null && root.wantsHover
    }

    // The same calls the pointer makes, asked for by name, so a click or a
    // tooltip asked for over IPC cannot behave differently from a real one.
    Connections {
        target: PanelModel
        function onClickRequested(widgetId: string, screen: string): void {
            if (root.entry?.id === widgetId && screen === root.screenName)
                root.widget?.handleActivate(Qt.LeftButton);
        }
        function onTooltipRequested(widgetId: string, screen: string): void {
            if (root.entry?.id !== widgetId || screen !== root.screenName)
                return;
            root.tooltipForced = true;
            tooltipForceTimer.restart();
        }
    }

    readonly property bool wantsHover: root.widget?.wantsHover ?? false
    readonly property bool wantsWheel: root.widget?.wantsWheel ?? false
    readonly property bool interactive: root.wantsHover || root.wantsWheel || !!root.widget?.popout

    implicitWidth: host.implicitWidth
    implicitHeight: host.implicitHeight

    // The zone is a positioner, and a positioner skips invisible children, so
    // a widget with nothing to show leaves no gap and no stray spacing.
    visible: root.widget?.present ?? true

    Component.onCompleted: PanelModel.addSlot(root)
    Component.onDestruction: {
        PanelModel.removeSlot(root);
        PanelModel.popoutClosed(root);
    }

    // ---- tooltip ----------------------------------------------------------
    //
    // Shown once the pointer has rested on the widget for a moment, never
    // while its popout is open, and gone at the first press.
    //
    // Hover reaches a widget one of two ways. One that asked for it gets it
    // through the MouseArea below, which covers the widget; the rest have their
    // own HoverHandler, which the MouseArea leaves alone because it is not
    // listening for hover. Each is read from where it actually arrives, so
    // neither route can hide the pointer from the tooltip.
    readonly property string tooltipText: root.widget?.tooltip ?? ""
    readonly property bool pointerOver: root.wantsHover ? mouse.containsMouse : (root.widget?.hovered ?? false)

    property bool tooltipDue: false
    property bool tooltipForced: false

    onPointerOverChanged: {
        root.tooltipDue = false;
        if (root.pointerOver)
            tooltipDelay.restart();
        else
            tooltipDelay.stop();
    }

    Timer {
        id: tooltipDelay
        interval: 600
        onTriggered: root.tooltipDue = true
    }

    Timer {
        id: tooltipForceTimer
        interval: 4000
        onTriggered: root.tooltipForced = false
    }

    WidgetHost {
        id: host
        anchors.fill: parent
        entry: root.entry
        bar: root.bar
        screenName: root.screenName
        widgetConfig: root.widgetConfig
    }

    MouseArea {
        id: mouse
        anchors.fill: parent

        // A widget that asked for nothing stays click-through, so a decorative
        // widget cannot accidentally swallow input meant for the panel.
        enabled: root.interactive
        visible: root.interactive
        hoverEnabled: root.wantsHover
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onPositionChanged: event => {
            if (root.wantsHover)
                root.widget.handleHover(root.bar.horizontal ? event.x : event.y, root.bar.horizontal);
        }

        onExited: if (root.wantsHover) root.widget.dismissPopout()

        onPressed: {
            root.tooltipDue = false;
            root.tooltipForced = false;
            // A press on any other widget closes the popout that is open, as
            // clicking the taskbar closes the Start menu.
            PanelModel.pressed(root);
        }

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

    // A widget that declares a popout gets a window for it, beside itself. The
    // widget supplies the contents and never touches placement -- which is
    // what lets a plugin have a popout without knowing where on the panel it
    // sits or which edge the panel is on.
    //
    // A layer surface rather than an xdg popup, deliberately. Wayland only
    // grants a popup the keyboard if its parent surface has already received
    // input, so a popup-based launcher can be focused by clicking the button
    // but never by a keybinding or `rmpr launcher` -- the panel has had no
    // input in that case, and the grab is refused. A layer surface asks for
    // keyboard focus directly and works either way.
    EdgeWindow {
        id: popout

        readonly property bool wanted: !!root.widget?.popout && !!root.widget?.popoutVisible
        readonly property Item popoutContent: content.item as Item

        slot: root
        bar: root.bar
        label: `popout '${root.entry?.id}'`
        centre: root.popoutCentre
        shadowMargin: 28

        visible: popout.wanted

        // Exclusive, not on-demand.
        //
        // `focusable` maps to on-demand keyboard focus, which means Wayland
        // hands over the keyboard only once the surface has been clicked -- so
        // a launcher opened from a keybinding or from `rmpr launcher` could
        // never be typed into, which is what the shell has been shipping with
        // and apologising for. Exclusive asks for the keyboard as soon as the
        // surface is mapped, which is exactly what a launcher wants, and it is
        // requested only by a popout that says it needs the keyboard -- the
        // rest ask for None and take nothing away from the window the user was
        // working in.
        WlrLayershell.keyboardFocus: (root.widget?.popoutGrabsFocus ?? false)
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        // The contents, the padding they sit in, and room for the shadow.
        readonly property int padding: root.widget?.popoutPadding ?? 20
        implicitWidth: (popout.popoutContent?.implicitWidth ?? 0) + 2 * popout.padding + 2 * popout.shadowMargin
        implicitHeight: (popout.popoutContent?.implicitHeight ?? 0) + 2 * popout.padding + 2 * popout.shadowMargin

        // Only the card takes the pointer. A click in its shadow goes to
        // whatever is beneath -- the surface that closes the popout.
        mask: Region { item: card }

        // Frosted behind, where the compositor offers it.
        BackgroundEffect.blurRegion: Theme.translucent ? popout._blur : null
        readonly property Region _blur: Region { item: card; radius: card.radius }

        // One popout open at a time, closed by a click anywhere else: see
        // PanelModel. A preview that follows the pointer closes by itself and
        // stays out of it. Followed as a pair rather than at the moment the
        // popout opens, because a widget can turn one kind into the other
        // while it stays open -- the task list's preview becomes its menu on
        // a right click.
        readonly property bool modal: popout.wanted && (root.widget?.popoutClosesOnOutsideClick ?? true)

        onModalChanged: {
            if (popout.modal)
                PanelModel.popoutOpened(root);
            else
                PanelModel.popoutClosed(root);
        }

        // Tell the panel, so it takes the keyboard for as long as this is
        // open and forwards what it receives here. A popout that only displays
        // something does not ask, and the panel stays out of the way.
        onWantedChanged: {
            if (popout.wanted)
                enter.restart();
            if (!root.bar)
                return;
            if (popout.wanted && (root.widget?.popoutGrabsFocus ?? false))
                root.bar.openPopout = popout.popoutContent;
            else if (root.bar.openPopout === popout.popoutContent)
                root.bar.openPopout = null;
        }

        // It rises out of the panel as it appears.
        property real shown: 1
        NumberAnimation {
            id: enter
            target: popout
            property: "shown"
            from: 0
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }

        RectangularShadow {
            anchors.fill: card
            radius: card.radius
            blur: 40
            offset.y: 12
            color: Theme.shadow
            opacity: popout.shown
        }

        Rectangle {
            id: card

            x: popout.shadowMargin
            y: popout.shadowMargin
            width: parent.width - 2 * popout.shadowMargin
            height: parent.height - 2 * popout.shadowMargin
            radius: Math.min((root.widget?.popoutRadius ?? -1) >= 0 ? root.widget.popoutRadius : Theme.radius,
                             width / 2, height / 2)
            color: Theme.glass
            border.width: 1
            border.color: Theme.out
            opacity: popout.shown

            transform: Translate {
                readonly property real d: (1 - popout.shown) * 14
                x: popout.edge === "left" ? -d : popout.edge === "right" ? d : 0
                y: popout.edge === "top" ? -d : popout.edge === "bottom" ? d : 0
            }

            // The panel forwards its keys here as well, for the case where
            // the panel itself holds the keyboard because it was clicked.
            focus: true
            Keys.forwardTo: popout.popoutContent ? [popout.popoutContent] : []

            Loader {
                id: content
                anchors.fill: parent
                anchors.margins: popout.padding
                // Built only while shown: a popout that is never opened should
                // cost nothing, and one that is closed should not keep state.
                active: popout.wanted
                sourceComponent: root.widget?.popout ?? null
            }
        }
    }

    // The tooltip: a second window, because a tooltip has to escape the panel
    // just as a popout does, and the popout's is spoken for. The first line is
    // the name of the thing, any further lines detail.
    EdgeWindow {
        id: tip

        readonly property var lines: root.tooltipText.split("\n")

        slot: root
        bar: root.bar
        label: `tooltip '${root.entry?.id}'`
        gap: 10
        centre: (root.widget?.tooltipCentre ?? -1) >= 0
            ? root.widget.tooltipCentre
            : ((root.bar?.horizontal ?? true) ? root.width : root.height) / 2

        visible: root.tooltipText.length > 0 && !popout.wanted
                 && ((root.tooltipDue && root.pointerOver) || root.tooltipForced)

        // Takes no input at all: a pointer that strays onto a tooltip must not
        // be caught by it, and the widget under it must stay reachable.
        mask: Region {}

        implicitWidth: tipColumn.width + 24
        implicitHeight: tipColumn.implicitHeight + 14

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.tipBg

            Column {
                id: tipColumn
                anchors.centerIn: parent
                width: Math.min(360, Math.max(tipFirst.implicitWidth, tipRest.visible ? tipRest.implicitWidth : 0))
                spacing: 2

                PanelText {
                    id: tipFirst
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: tip.lines[0] ?? ""
                    color: Theme.tipFg
                    font.pixelSize: 13
                }

                PanelText {
                    id: tipRest
                    visible: tip.lines.length > 1
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: tip.lines.slice(1).join("\n")
                    color: Theme.tipFgMut
                    font.pixelSize: 12
                }
            }
        }
    }
}
