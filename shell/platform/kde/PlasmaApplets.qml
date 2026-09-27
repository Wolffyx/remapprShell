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
//
// Both are applications somebody opened, so both go through Launch, into a
// scope of their own: a restart of the shell must not close the mixer or the
// settings window in front of the user. Where the shell already hosts
// Plasma's services (PlasmaServices), plasmawindowed is that process, and the
// window opens in it -- the scope then holds only the request, for the moment
// it takes to hand it over.

import QtQuick
import qs.platform.system

QtObject {
    function open(applet) {
        if (!applet)
            return;
        Launch.command(["plasmawindowed", applet], "org.kde.plasmawindowed");
    }

    // A page of System Settings, by its module name ("kcm_nightlight"), for
    // what no applet offers.
    function openSettings(kcm) {
        if (!kcm)
            return;
        Launch.command(["systemsettings", kcm], "systemsettings");
    }
}
