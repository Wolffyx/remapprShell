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

    // The hosting panel. Exposes exactly three things: `position`
    // ("top"/"bottom"/"left"/"right"), `horizontal`, and `thickness`.
    required property var bar

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

    // Shown when the widget is activated. Null means the widget has no popout.
    // The panel builds the window; the widget supplies only the contents, so a
    // widget never has to know where on the panel it sits or which edge the
    // panel is on.
    property Component popout: null
    property bool popoutVisible: false

    // Whether the popout needs the keyboard. A popout that only displays
    // something should not steal focus from whatever the user was typing in,
    // so this is opt-in rather than always on.
    property bool popoutGrabsFocus: false

    // Whether a click anywhere else closes the popout, as a menu's does --
    // and whether opening it closes whichever other popout is open. A popout
    // that follows the pointer, like the task list's preview, closes by
    // itself when the pointer leaves, and turns this off.
    property bool popoutClosesOnOutsideClick: true

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

    // ---- signals to the host -------------------------------------------

    signal requestPopout(string name, real centre)
    signal dismissPopout

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
}
