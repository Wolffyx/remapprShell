// One position in a zone: the widget, plus the interaction it asked for.
//
// The panel reads capabilities and calls the matching function. It never asks
// what a widget *is*. That is the difference between a panel that can host
// widgets it has never heard of and one that needs editing for each new type.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.core
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
    EdgeWindow {
        id: popout

        readonly property bool wanted: !!root.widget?.popout && !!root.widget?.popoutVisible
        readonly property Item popoutContent: content.item as Item

        // The shadow's own numbers, and the room the window keeps for them.
        // The margin is derived rather than written down twice: a margin
        // smaller than blur + drop cuts the blur off square against the edge
        // of the window, and on a screen that cut reads as a second card
        // sitting behind the card.
        //
        // Smaller than it was. At blur 40 and drop 12 the shadow was a 52 px
        // band of dimmed wallpaper around a card whose own background is
        // blurred, and the difference between the two drew a second rectangle
        // -- reported, twice, as "another popup underneath". A shadow should
        // say the card is above the wallpaper, not be a shape of its own.
        readonly property real shadowBlur: Theme.shadows ? 22 : 0
        readonly property real shadowDrop: Theme.shadows ? 7 : 0

        slot: root
        bar: root.bar
        label: `popout '${root.entry?.id}'`
        centre: root.popoutCentre
        align: root.widget?.popoutAlign ?? "centre"
        shadowMargin: Math.ceil(popout.shadowBlur + popout.shadowDrop)

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
        readonly property int askedWidth: root.widget?.popoutWidth ?? -1
        implicitWidth: (popout.askedWidth >= 0 ? popout.askedWidth
                                               : (popout.popoutContent?.implicitWidth ?? 0))
                       + 2 * popout.padding + popout.padH
        implicitHeight: (popout.popoutContent?.implicitHeight ?? 0) + 2 * popout.padding
                        + popout.padV

        // Only the card takes the pointer: a click in its shadow goes to
        // whatever is beneath, which is the surface that closes the popout.
        //
        // Except when this popout has asked for the keyboard. A layer surface
        // that asks for exclusive keyboard focus AND carries an input mask is
        // mapped by KWin 6.7.5 and then drawn as nothing at all -- the window
        // is there, at the right size on the right screen, and the log says so,
        // but the screen stays empty. That is what "the start menu does not
        // open" was. Either one alone is fine: the key sheet takes the keyboard
        // and has no mask, and every popout that masks takes no keyboard.
        //
        // The keyboard wins, because a launcher nobody can see is worse than a
        // band of shadow that swallows a click instead of passing it through.
        // Found on a real screen; every offscreen render of this menu was
        // perfect, because the harness strips both properties.
        //
        // What that band must not do is reach back over the panel. It did, by
        // the whole shadow margin, so the start button sat underneath the
        // start menu's own window and a second click on it went nowhere --
        // the menu could be opened and not closed. EdgeWindow caps the room
        // on the panel side at the gap for exactly this.
        mask: (root.widget?.popoutGrabsFocus ?? false) ? null : cardOnly
        readonly property Region cardOnly: Region { item: card }

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
            if (popout.wanted) {
                popout.wantedAt = Date.now();
                enter.restart();
                // Any popout, not only a modal one: a hover preview beside an
                // open panel menu is still two cards on screen at once.
                PanelModel.closeOpenMenu();
            }
            if (!root.bar)
                return;
            if (popout.wanted && (root.widget?.popoutGrabsFocus ?? false))
                root.bar.openPopout = popout.popoutContent;
            else if (root.bar.openPopout === popout.popoutContent)
                root.bar.openPopout = null;
        }

        // When it was asked for, against which the build below is measured.
        property real wantedAt: 0

        // It rises out of the panel as it appears.
        property real shown: 1
        NumberAnimation {
            id: enter
            target: popout
            property: "shown"
            from: 0
            to: 1
            duration: Theme.animationMs
            easing.type: Easing.OutCubic
        }

        RectangularShadow {
            visible: Theme.shadows
            anchors.fill: card
            radius: card.radius
            blur: popout.shadowBlur
            offset.y: popout.shadowDrop
            color: Theme.shadow
            opacity: popout.shown
        }

        Rectangle {
            id: card

            x: popout.padLeft
            y: popout.padTop
            width: parent.width - popout.padH
            height: parent.height - popout.padV
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

                // How long that build took. "The popouts feel slow" needs a
                // number before anything is optimised, and the build is the
                // part of the delay this project owns -- the rest is the
                // compositor mapping a surface, which nothing here can time.
                onLoaded: Log.debug("panel",
                    `popout '${root.entry?.id}' built in ${Date.now() - popout.wantedAt} ms`)
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
