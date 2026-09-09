// What every launcher provider implements.
//
// The panel button, the keybinding and `rmpr launcher` all call
// LauncherService.open(). One dispatch point, so adding a provider never means
// touching the things that trigger it.

import QtQuick

QtObject {
    id: root

    // Identifier used in configuration. Not called `id`, which QML reserves.
    required property string providerId

    property string label: root.providerId

    // Whether this provider can run here. Providers probe once at startup; an
    // unavailable one is hidden rather than offered and then failing when
    // clicked.
    property bool available: false

    // True when the provider draws inside one of our own windows, which is
    // what decides whether its popup can be anchored to the panel button.
    property bool embedded: false

    property bool visible: false

    // mode is "apps", "search" or "run". A provider that cannot distinguish
    // them may ignore it.
    function open(mode) {}
    function openWithQuery(query) { root.open("search"); }
    function close() {}

    function toggle(mode) {
        if (root.visible)
            root.close();
        else
            root.open(mode ?? "apps");
    }
}
