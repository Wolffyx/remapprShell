pragma ComponentBehavior: Bound

// A widget's popout: the card beside the panel, its shadow, its entrance, and
// the invisible bridge back to the button.
//
// WidgetSlot makes one for every widget and says where it points; this is
// the window itself. The widget supplies the contents and never touches
// placement -- see WidgetSlot for why that is, and for why this is a layer
// surface rather than an xdg popup.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.ui.primitives
import qs.domain.panel
import qs.domain.theme
import qs.features.panel.model

EdgeWindow {
    id: popout

    // The widget whose popout this is -- null until it has loaded -- and the
    // entry that put it on the panel, for the log.
    required property BarWidget widget
    required property var entry

    readonly property bool wanted: !!popout.widget?.popout && !!popout.widget?.popoutVisible
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

    label: `popout '${popout.entry?.id}'`
    align: popout.widget?.popoutAlign ?? "centre"
    shadowMargin: Math.ceil(popout.shadowBlur + popout.shadowDrop)
    tail: popout.widget?.popoutTail ?? false

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
    WlrLayershell.keyboardFocus: (popout.widget?.popoutGrabsFocus ?? false)
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    // The contents, the padding they sit in, and room for the shadow.
    readonly property int padding: popout.widget?.popoutPadding ?? 20
    readonly property int askedWidth: popout.widget?.popoutWidth ?? -1
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
    //
    // A popout with a bridge takes the pointer on it as well, so the
    // pointer crossing from the button to the card never leaves the
    // popout: the bridge is the way there.
    mask: (popout.widget?.popoutGrabsFocus ?? false) ? null : popout.tail ? popout.cardAndBridge : popout.cardOnly
    readonly property Region cardOnly: Region { item: card }
    readonly property Region cardAndBridge: Region {
        item: card
        regions: [popout._bridgeInput]
    }
    readonly property Region _bridgeInput: Region {
        x: Math.round(popout.bridgeBox.x)
        y: Math.round(popout.bridgeBox.y)
        width: Math.round(popout.bridgeBox.width)
        height: Math.round(popout.bridgeBox.height)
    }

    // Frosted behind, where the compositor offers it: the card, and only
    // the card. The bridge is not drawn, so nothing of it may show -- a
    // blurred strip under it would be a neck by another name.
    BackgroundEffect.blurRegion: Theme.translucent ? popout._blur : null
    readonly property Region _blur: Region { item: card; radius: card.radius }

    // ---- the bridge ---------------------------------------------------------
    //
    // A popout that asked for one (`popoutTail`) takes the pointer across
    // the gap between its card and the panel, on a strip exactly as wide
    // as the widget's button (`popoutTailWidth`), from the card's edge to
    // the panel's, on the point the widget named. Nothing of it is drawn
    // -- a visible neck was tried and not wanted (2026-09-24) -- it only
    // keeps the pointer going up from a button to its card on the popout,
    // so the card does not start closing on the way. The window already
    // reaches the panel's edge for it (EdgeWindow.tail).
    readonly property real tailWidth: (popout.widget?.popoutTailWidth ?? -1) > 0
        ? popout.widget.popoutTailWidth : (popout.widget?.tileSize ?? 40)
    readonly property var bridge: Tail.bridge(popout.horizontal ? card.width : card.height,
                                              popout.slotStart + popout.centre - popout.placedAlong - popout.padLead,
                                              popout.tailWidth, popout.reach)
    readonly property var bridgeBox: Tail.box(popout.bridge, card.width, card.height, popout.edge, card.x, card.y)

    // The pointer on the card or its bridge. Told to the widget (see the
    // Binding in WidgetSlot): the task list keeps its preview open on it,
    // where it used to watch its own contents -- which stop short of the
    // card's padding, and of the bridge, so crossing either started the
    // countdown to closing.
    readonly property bool hovered: popout.visible && (cardHover.hovered || bridgeHover.hovered)

    // One popout open at a time, closed by a click anywhere else: see
    // PanelModel. A preview that follows the pointer closes by itself and
    // stays out of it. Followed as a pair rather than at the moment the
    // popout opens, because a widget can turn one kind into the other
    // while it stays open -- the task list's preview becomes its menu on
    // a right click.
    readonly property bool modal: popout.wanted && (popout.widget?.popoutClosesOnOutsideClick ?? true)

    onModalChanged: {
        if (popout.modal)
            PanelModel.popoutOpened(popout.slot);
        else
            PanelModel.popoutClosed(popout.slot);
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
        if (!popout.bar)
            return;
        if (popout.wanted && (popout.widget?.popoutGrabsFocus ?? false))
            popout.bar.openPopout = popout.popoutContent;
        else if (popout.bar.openPopout === popout.popoutContent)
            popout.bar.openPopout = null;
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
        radius: Math.min((popout.widget?.popoutRadius ?? -1) >= 0 ? popout.widget.popoutRadius : Theme.radius,
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

        HoverHandler { id: cardHover }

        // The bridge takes the pointer as the card does, and draws nothing.
        Item {
            readonly property var box: Tail.box(popout.bridge, card.width, card.height, popout.edge, 0, 0)
            visible: popout.tail
            x: box.x
            y: box.y
            width: box.width
            height: box.height
            HoverHandler { id: bridgeHover }
        }

        Loader {
            id: content
            anchors.fill: parent
            anchors.margins: popout.padding
            // Built only while shown: a popout that is never opened should
            // cost nothing, and one that is closed should not keep state.
            active: popout.wanted
            sourceComponent: popout.widget?.popout ?? null

            // How long that build took. "The popouts feel slow" needs a
            // number before anything is optimised, and the build is the
            // part of the delay this project owns -- the rest is the
            // compositor mapping a surface, which nothing here can time.
            onLoaded: Log.debug("panel",
                `popout '${popout.entry?.id}' built in ${Date.now() - popout.wantedAt} ms`)
        }
    }
}
