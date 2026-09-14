// The Quickshell renderer: one layer-shell panel per screen.
//
// It knows about zones and ordering only through PanelModel, and about widgets
// only through WidgetHost. It never asks what a widget is. How the panel is
// drawn -- a strip, a floating bar, islands -- is PanelSurface's; this is the
// window around it: where it sits, what it reserves, when it hides.

import QtQuick
import Quickshell
import Quickshell.Wayland
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

    // How it is drawn, and the sizes widgets share: the gap between them and
    // the size of a tray or status icon.
    readonly property string style: PanelModel.styleFor(root.screenName)
    readonly property int spacing: PanelModel.spacingFor(root.screenName)
    readonly property int iconSize: PanelModel.iconSizeFor(root.screenName)

    // A floating bar and islands keep clear of the screen edge; the whole
    // strip, including that margin, is what the panel takes from the screen
    // and what a popout opens beyond.
    readonly property int edgeGap: root.style === "full" ? 0 : 14
    readonly property int extent: root.thickness + root.edgeGap

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
    readonly property bool revealOnHover: PanelModel.revealOnHoverFor(root.screenName)
    readonly property int revealStrip: 3

    property bool pointerInside: false

    // A popout keeps it out: the panel collapsing while a menu opened from it
    // is still on screen would drag the menu away from what opened it.
    readonly property bool revealed: !root.autoHide || root.pointerInside || root.openPopout !== null
                                     || PanelModel.openPopoutSlot?.screenName === root.screenName

    // Leaving is delayed; arriving is not. A panel that vanished the instant
    // the pointer crossed its edge would flicker on the way to a widget near
    // it.
    readonly property Timer _hideTimer: Timer {
        interval: 400
        onTriggered: root.pointerInside = false
    }

    // With reveal on hover turned off, the sliver at the edge does nothing:
    // the panel comes back only with a popout opened from a key.
    function setPointerInside(inside) {
        if (inside) {
            if (!root.revealed && !root.revealOnHover)
                return;
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
    readonly property int visibleThickness: root.revealed ? root.extent : root.revealStrip

    implicitHeight: root.horizontal ? root.visibleThickness : 0
    implicitWidth: root.horizontal ? 0 : root.visibleThickness

    Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // Reserve the strip so maximised windows stop at the panel rather than
    // being covered by it -- unless it hides, in which case reserving it would
    // defeat the point.
    exclusiveZone: root.autoHide ? 0 : root.extent

    color: "transparent"

    // Only what is drawn takes the pointer. The margin a floating bar keeps
    // from the edge, and the gaps between islands, let a click through to the
    // window beneath. While hidden, the whole sliver is the target.
    mask: root.revealed && root.style !== "full" ? surface.shape : null

    // Blurred behind, where the compositor offers it -- KWin does, through
    // ext-background-effect -- so a translucent panel reads as frosted glass
    // rather than as a tinted hole.
    BackgroundEffect.blurRegion: Theme.translucent && root.revealed ? surface.shape : null

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

    Item {
        id: slider

        // Keeps its full extent even while the window is a sliver, and slides
        // out of view instead of being squashed: anchoring it to the edge away
        // from the screen edge means what stays visible is the panel's own
        // inner edge. Squashing it would re-lay-out every widget twice per
        // reveal, for something nobody sees.
        width: root.horizontal ? parent.width : root.extent
        height: root.horizontal ? root.extent : parent.height

        // Positioned, not anchored. Anchors switched by bindings do not
        // survive the panel changing edge while it runs: the new anchor can be
        // applied while the old one on the same axis is still set, and is
        // dropped. Moving the panel from the left edge back to the bottom left
        // the right-hand widgets off the end of the screen until a restart. A
        // plain x/y binding is simply re-evaluated.
        x: root.position === "left" ? parent.width - width : 0
        y: root.position === "top" ? parent.height - height : 0

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

        // A press on the panel between widgets, or on one that takes no
        // clicks, closes an open popout too. Beneath the surface, so a widget
        // that does take the press gets it first.
        //
        // A right click there opens the panel's own menu, which is what every
        // other desktop does and what this one did nothing at all about.
        MouseArea {
            id: empty

            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: PanelModel.pressed(null)
            onClicked: event => {
                if (event.button !== Qt.RightButton) {
                    root.menuOpen = false;
                    return;
                }
                root.menuAt = root.horizontal ? event.x : event.y;
                root.menuOpen = true;
            }
        }

        // The panel's own menu. One per panel, built when it is first asked
        // for: a menu nobody opens should cost nothing.
        LazyLoader {
            id: panelMenuLoader
            loading: false
            activeAsync: root.menuOpen

            PanelMenu {
                id: panelMenu

                slot: slider
                bar: root
                at: root.menuAt
                visible: root.menuOpen
                onChosen: root.menuOpen = false
            }
        }

        PanelSurface {
            id: surface
            anchors.fill: parent
            bar: root
        }
    }

    // Whether the panel's own menu is up. Held here rather than in the menu so
    // a click anywhere else can close it, the way a popout is closed.
    //
    // Told to PanelModel as it changes, because a popout and this menu are the
    // same kind of thing to everyone looking at the screen, and only one of
    // them should be up. See PanelModel.menuOpened.
    property bool menuOpen: false

    onMenuOpenChanged: {
        if (root.menuOpen)
            PanelModel.menuOpened(root);
        else
            PanelModel.menuClosed(root);
    }

    // Asked for by PanelModel when something else wants the screen.
    function closeMenu(): void {
        root.menuOpen = false;
    }

    // Where along the panel the click that opened it was. Held here, not on
    // the menu: an id inside a LazyLoader's component cannot be reached from
    // outside it.
    property real menuAt: 0

    // A click anywhere off the panel closes an open popout, as a menu's does
    // everywhere else. A layer surface has no popup grab to do that for it, so
    // this is a transparent surface over the rest of the screen. It leaves the
    // panel's own strip uncovered, so a click on another widget still reaches
    // that widget. One per panel, so a click on the other monitor closes it as
    // well. The click that closes the popout goes no further -- as in Plasma,
    // where the same click is taken by the popup's grab.
    //
    // Mapped always, and made deaf rather than hidden when there is nothing to
    // close.
    //
    // It shares the top layer with the popouts now that those have come off
    // the overlay layer -- where they sat above full-screen windows, over
    // Spectacle's region selector and over games. Two surfaces on one layer
    // stack in the order they were mapped, so a surface that maps and unmaps
    // with the popout is a race the popout can lose, and losing it means every
    // click on a popout closes it instead of reaching it. One that is mapped
    // from the start always loses, which is the answer.
    PanelWindow {
        id: catcher
        screen: root.screen
        visible: true

        // Takes nothing at all while no popout is open: an empty input region,
        // so the desktop and every window below behave as if it were not here.
        readonly property Region deaf: Region {}
        mask: PanelModel.openPopoutSlot !== null || root.menuOpen ? null : catcher.deaf

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins.top: root.position === "top" ? root.extent : 0
        margins.bottom: root.position === "bottom" ? root.extent : 0
        margins.left: root.position === "left" ? root.extent : 0
        margins.right: root.position === "right" ? root.extent : 0

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: {
                PanelModel.closeOpenPopout();
                root.menuOpen = false;
            }
        }
    }

    Component.onCompleted: Log.info("panel",
        `up on ${modelData.name} (${modelData.width}x${modelData.height}, ${root.position}, ${root.thickness}px, ${root.style}`
        + `${root.autoHide ? ", hidden until pointed at" : ""})`)
}
