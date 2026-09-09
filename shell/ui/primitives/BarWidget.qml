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
