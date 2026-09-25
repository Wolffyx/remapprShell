// The contract every panel widget implements -- built-in and third-party alike.
//
// Widgets declare capabilities rather than the panel switching on their id.
// That distinction is the whole point: a registry that only maps id -> Component
// still leaves hover, popout and scroll behaviour as a hardcoded chain of id
// comparisons in the panel, which is exactly what makes such a panel unable to
// host widgets it does not already know about.
//
// The panel asks `wantsHover` / `wantsWheel` and calls the corresponding
// function. It never asks what a widget *is*.

import QtQuick

Item {
    id: root

    // ---- injected by the host -----------------------------------------

    // The hosting panel. Exposes `position` ("top"/"bottom"/"left"/"right"),
    // `horizontal` and `thickness`, and the two sizes widgets share:
    // `iconSize`, for a tray or status icon, and `spacing`, between widgets.
    required property var bar

    // The panel's thickness -- 40 until there is a panel to ask -- and whether
    // it runs down the side of the screen rather than along an edge. Nearly
    // every widget needs one or the other, so they are read here once rather
    // than in twenty places.
    readonly property real barThickness: root.bar?.thickness ?? 40
    readonly property bool barVertical: !(root.bar?.horizontal ?? true)

    // The design's proportions are for a 64 px panel; a widget scales from
    // this rather than hardcoding sizes that only fit one thickness.
    readonly property real unit: root.barThickness / 64
    readonly property int panelIconSize: root.bar?.iconSize ?? 19

    // The side of a square panel button: the design's 40 at 64 px, never
    // under 22. What most widgets hand their BarButton; the search field, the
    // task view and the sidebar keep BarButton's own, larger default.
    readonly property int tileSize: Math.max(22, Math.round(40 * root.unit))

    // This widget's own configuration: its manifest defaults merged with the
    // user's overrides. Never the whole shell config.
    required property var widgetConfig

    // The output this instance is on. Widgets that show per-monitor state
    // (workspaces, active window) need it; most do not.
    required property string screenName

    // ---- capabilities, overridden by the widget ------------------------

    // Not readonly: a widget declares its capabilities by assigning these, and
    // a readonly property in the base type cannot be overridden.
    property bool wantsHover: false
    property bool wantsWheel: false

    // Whether a right click on this widget means anything to it. A widget that
    // says nothing gets the panel's own menu instead, the way a right click on
    // a plasmoid with no menu of its own opens Plasma's panel menu -- so the
    // click always does something, rather than being swallowed by whichever
    // widget happened to be under the pointer.
    property bool wantsRightClick: false

    // Shown when the widget is activated. Null means the widget has no popout.
    // The panel builds the window; the widget supplies only the contents, so a
    // widget never has to know where on the panel it sits or which edge the
    // panel is on.
    property Component popout: null
    property bool popoutVisible: false

    // How the panel asks this widget to put its popout away -- another one
    // opened, or a click landed elsewhere. It is a function rather than the
    // panel writing `popoutVisible` directly, because a widget whose
    // `popoutVisible` is a *binding* loses that binding the moment anything
    // assigns to it, and never opens again. The launcher was exactly that:
    // one click outside the start menu and the start button did nothing for
    // the rest of the session. A widget that keeps its open state somewhere
    // else overrides this and puts it back there.
    function closePopout() {
        root.popoutVisible = false;
    }

    // Whether the popout needs the keyboard. A popout that only displays
    // something should not steal focus from whatever the user was typing in,
    // so this is opt-in rather than always on.
    property bool popoutGrabsFocus: false

    // Whether a click anywhere else closes the popout, as a menu's does --
    // and whether opening it closes whichever other popout is open. A popout
    // that follows the pointer, like the task list's preview, closes by
    // itself when the pointer leaves, and turns this off.
    property bool popoutClosesOnOutsideClick: true

    // How the popout lines up with this widget along the panel: "centre", the
    // default, or "start" -- its near edge level with the widget's. A popout
    // about as wide as its icon wants centring; a menu many times wider than
    // its button does not, because centred and then pushed back on screen it
    // ends up level with neither the button nor anything else.
    property string popoutAlign: "centre"

    // How wide the popout's card is; -1 takes it from the contents.
    //
    // It belongs here rather than in the contents because the panel anchors
    // the contents to fill the card: a width set inside them is overwritten,
    // and what was left was the width of the longest line of text -- which
    // changes with the locale, so the calendar was a different size in every
    // language.
    property int popoutWidth: -1

    // How far in from the popout's edge its contents sit, and how round it
    // is; -1 is the theme's own rounding. A menu wants less of both than a
    // panel of controls does.
    property int popoutPadding: 20
    property real popoutRadius: -1

    // Whether the popout takes the pointer across the gap to the panel, on
    // an invisible bridge `popoutTailWidth` wide (-1 is `tileSize`) from its
    // card to the panel's edge, on the point the widget named in
    // requestPopout. For a popout that is about one thing on the panel and
    // closes when the pointer leaves it -- the taskbar's preview, reached by
    // moving up from its button. Nothing of the bridge is drawn: the card
    // looks as every card does.
    property bool popoutTail: false
    property real popoutTailWidth: -1

    // Whether the pointer is on the popout: anywhere on its card, the border
    // and padding round the contents included, and on its bridge. Set by the
    // panel. A popout that closes by itself when the pointer leaves it reads
    // this rather than hovering its own contents, which stop short of all
    // three.
    property bool popoutHovered: false

    // How long the widget may be along the panel before it runs into its
    // neighbours; -1 for no limit. Set by the panel. Most widgets have a size
    // of their own and ignore it; one that can give way -- the task list,
    // cutting its titles short -- fits itself into it.
    property real room: -1

    // Whether this widget fits itself into `room`. The panel counts one that
    // does as taking nothing when it shares the bar out, since it will take
    // whatever is left -- and so no zone's room depends on another zone's
    // room, which is the loop the shares used to go round.
    property bool givesWay: false

    // Whether there is anything to show. A battery widget on a desktop, or a
    // Bluetooth one on a machine with no adapter, sets this false and takes no
    // room on the panel -- rather than leaving a gap, or an icon for hardware
    // that is not there, which reads as broken.
    property bool present: true

    // A line or two shown when the pointer rests on the widget and no popout
    // is open. Empty for none. A widget made of several things -- the tray --
    // changes it as the pointer moves, and says where it points with
    // `tooltipCentre`, measured along the panel from the widget's start; -1
    // is the middle of the widget.
    property string tooltip: ""
    property real tooltipCentre: -1

    // Whether the pointer is over the widget. The panel times the tooltip from
    // it for widgets that do not take hover from the panel; those that do
    // (`wantsHover`) are timed from the panel's own hover instead.
    //
    // A widget that takes hover from the panel is covered by the panel's
    // MouseArea, which then keeps the pointer from its own HoverHandler. The
    // panel passes what it sees down as `hostHovered`, so `hovered` means the
    // same thing for every widget, whichever route the pointer took.
    readonly property bool hovered: _hover.hovered || root.hostHovered
    property bool hostHovered: false

    HoverHandler { id: _hover }

    // ---- behaviour, overridden by the widget ---------------------------

    function handleHover(position, horizontal) {}
    function handleWheel(delta) {}
    function handleActivate(button) {}

    // ---- for a widget made of several things ----------------------------
    //
    // The panel tells a widget where the pointer is along it, and a widget of
    // several parts -- the task buttons, the desktops, the status glyphs --
    // has to turn that into which part. They differ in width, so it is found
    // by where each one actually is rather than by dividing the position.

    // Which of `repeater`'s items is at `position` along the panel, or -1.
    // Each one's reach runs half of `spacing` out either side, so a gap
    // belongs to the parts beside it rather than to nothing. `origin` is
    // where their positioner starts inside the widget, measured the same way.
    function indexAlong(repeater, position, spacing, vertical, origin) {
        const p = position - (origin ?? 0);
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (!item)
                continue;
            const start = vertical ? item.y : item.x;
            const length = vertical ? item.height : item.width;
            if (p >= start - spacing / 2 && p < start + length + spacing / 2)
                return i;
        }
        return -1;
    }

    // The middle of item `index`, along the panel from the widget's start --
    // what `tooltipCentre` and requestPopout want -- or -1 without one.
    function centreAlong(repeater, index, vertical, origin) {
        const item = repeater.itemAt(index);
        if (!item)
            return -1;
        return (origin ?? 0) + (vertical ? item.y + item.height / 2 : item.x + item.width / 2);
    }

    // ---- signals to the host -------------------------------------------

    signal requestPopout(string name, real centre)
    signal dismissPopout

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
}
