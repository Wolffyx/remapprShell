pragma Singleton

// Plasma's own applets, opened in a window of their own.
//
// `plasmawindowed` hosts any Plasma applet outside a panel, including the ones
// compiled into a plugin rather than shipped as QML. This is how a widget
// offers everything Plasma's applet does -- the Wi-Fi password prompt, the
// mixer with a volume per application, Bluetooth pairing -- without
// reimplementing any of it, and without our panel having to be a Plasma panel.
//
// It registers itself as a unique DBus service (`org.kde.plasmawindowed`), so
// a second request is handed to the process already running rather than
// starting another one.

import QtQuick
import Quickshell

QtObject {
    function open(applet) {
        if (!applet)
            return;
        Quickshell.execDetached(["plasmawindowed", applet]);
    }

    // A page of System Settings, by its module name ("kcm_nightlight"), for
    // what no applet offers.
    function openSettings(kcm) {
        if (!kcm)
            return;
        Quickshell.execDetached(["systemsettings", kcm]);
    }
}
