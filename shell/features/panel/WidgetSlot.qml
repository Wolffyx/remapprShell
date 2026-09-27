pragma ComponentBehavior: Bound

// One position in a zone: the widget, plus the interaction it asked for.
//
// The panel reads capabilities and calls the matching function. It never asks
// what a widget *is*. That is the difference between a panel that can host
// widgets it has never heard of and one that needs editing for each new type.

import QtQuick
import qs.ui.primitives
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

    // What this slot takes along the panel whatever room it is given: all of
    // itself, or nothing for a widget that gives way. Read only from the
    // widget's own content, never from `room` -- see PanelSurface.
    readonly property real fixedLength: root.widget?.givesWay ? 0
        : root.horizontal ? root.implicitWidth : root.implicitHeight

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
        root.widget?.closePopout();
    }

    Connections {
        target: root.widget
        function onRequestPopout(name: string, centre: real): void {
            root.popoutCentre = centre;
        }
    }

    // Whether the pointer is on the popout, for a widget whose popout closes
    // by itself when the pointer leaves it. See `popout.hovered`.
    Binding {
        target: root.widget
        property: "popoutHovered"
        value: popout.hovered
        when: root.widget !== null
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

    // As thick as the bar, whatever the widget's own size. The widget still
    // draws at the size it asked for, centred, but the strip above and below
    // it belongs to it: on a bottom panel the last row of pixels on the screen
    // is the one a pointer thrown at the edge lands on, and a right click
    // there used to miss every widget and fall through to the panel itself.
    // A taskbar that is only clickable through its middle is the one thing
    // Fitts's law says a taskbar must not be.
    //
    // Only across the panel. The length along it is the widget's, as before --
    // a slot that claimed more would leave gaps in the row.
    readonly property bool horizontal: root.bar?.horizontal ?? true
    readonly property int barThickness: root.bar?.thickness ?? 0

    implicitWidth: root.horizontal ? host.implicitWidth : Math.max(host.implicitWidth, root.barThickness)
    implicitHeight: root.horizontal ? Math.max(host.implicitHeight, root.barThickness) : host.implicitHeight

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

    // Centred in the slot, at its own size across the panel: the slot grew to
    // the bar's thickness above, and a widget stretched to fill that would
    // draw a taller button rather than the same button in a taller target.
    WidgetHost {
        id: host
        anchors.centerIn: parent
        width: root.horizontal ? parent.width : host.implicitWidth
        height: root.horizontal ? host.implicitHeight : parent.height
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

        // A right click the widget has no use for opens the panel's own menu,
        // as it would have done had the click landed between two widgets.
        // Without this the strip above and below a widget -- which is the
        // widget's target now, and which is where a pointer thrown at the
        // screen edge lands -- swallowed the click and answered nothing.
        onClicked: event => {
            if (event.button === Qt.RightButton && !(root.widget?.wantsRightClick ?? false)) {
                const p = root.mapToItem(null, event.x, event.y);
                PanelModel.menuRequested(root.screenName, (root.bar?.horizontal ?? true) ? p.x : p.y);
                return;
            }
            root.widget?.handleActivate(event.button);
        }
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
    //
    // The window itself -- the card, its shadow, the bridge, the keyboard it
    // asks for and the mask it does not -- is SlotPopout.
    SlotPopout {
        id: popout

        slot: root
        bar: root.bar
        widget: root.widget
        entry: root.entry
        centre: root.popoutCentre
    }

    // The tooltip, in a window of its own (SlotTooltip). Shown by the rules
    // at the top of the tooltip section: after a rest, on request, and never
    // over this slot's own open popout.
    SlotTooltip {
        slot: root
        bar: root.bar
        label: `tooltip '${root.entry?.id}'`
        centre: (root.widget?.tooltipCentre ?? -1) >= 0
            ? root.widget.tooltipCentre
            : ((root.bar?.horizontal ?? true) ? root.width : root.height) / 2
        text: root.tooltipText

        visible: root.tooltipText.length > 0 && !popout.wanted
                 && ((root.tooltipDue && root.pointerOver) || root.tooltipForced)
    }
}
