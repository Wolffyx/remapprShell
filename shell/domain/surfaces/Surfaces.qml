pragma Singleton

// Which of the shell's full-screen surfaces is open, and on which screen:
// the sidebar, the key sheet, the session screen.
//
// Held here, below the features that draw them, so anything can ask for one
// -- a panel widget, the launcher's actions, IPC -- and the one place that
// draws them (shell.qml) reads the answer. Opening one closes the others:
// two full-screen things at once is never what was meant.

import QtQuick
import Quickshell

QtObject {
    id: root

    property bool sidebar: false
    property bool keys: false
    property bool session: false

    // What the session screen was opened for: "promptAll", "promptLogout",
    // "promptReboot" or "promptShutDown", as Plasma's prompt names them.
    property string sessionKind: "promptAll"

    // The screen they appear on; empty is the first.
    property string screen: ""

    readonly property string screenName: root.screen.length > 0 ? root.screen : (Quickshell.screens[0]?.name ?? "")

    function _only(which, screen) {
        root.sidebar = which === "sidebar";
        root.keys = which === "keys";
        root.session = which === "session";
        if (screen !== undefined)
            root.screen = screen ?? "";
    }

    function toggleSidebar(screen) { root._only(root.sidebar ? "" : "sidebar", screen); }
    function toggleKeys(screen) { root._only(root.keys ? "" : "keys", screen); }

    function openSession(kind, screen) {
        root.sessionKind = kind ?? "promptAll";
        root._only("session", screen);
    }

    function closeAll() { root._only(""); }
}
