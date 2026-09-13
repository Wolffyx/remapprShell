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

    // Alt+Tab, when this shell is the one drawing it rather than KWin.
    property bool windowSwitcher: false

    // A press of the switcher's key while it is already up. KWin takes the
    // key press before any client sees it, so a second Alt+Tab never reaches
    // the surface as a key at all -- it arrives here, as another call. The
    // counter is what the switcher watches; the delta is which way.
    property int windowSwitcherTick: 0
    property int windowSwitcherDelta: 1

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
        root.windowSwitcher = which === "windowSwitcher";
        if (screen !== undefined)
            root.screen = screen ?? "";
    }

    // Opened by a key that is still held, so it never toggles: pressing the
    // shortcut again while it is up steps through the list instead.
    function openWindowSwitcher(screen, delta) {
        root.windowSwitcherDelta = delta === undefined ? 1 : delta;
        if (root.windowSwitcher) {
            root.windowSwitcherTick += 1;
            return;
        }
        root.windowSwitcherTick = 0;
        root._only("windowSwitcher", screen);
    }

    function toggleSidebar(screen) { root._only(root.sidebar ? "" : "sidebar", screen); }
    function toggleKeys(screen) { root._only(root.keys ? "" : "keys", screen); }

    function openSession(kind, screen) {
        root.sessionKind = kind ?? "promptAll";
        root._only("session", screen);
    }

    function closeAll() { root._only(""); }
}
