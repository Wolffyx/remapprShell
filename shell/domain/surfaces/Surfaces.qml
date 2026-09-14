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

    // The switcher's key let go, which is what chooses.
    //
    // That release used to be a key event on the switcher's own surface, which
    // only works while the surface is up and holding the keyboard. A quick
    // Alt+Tab lets go before it is -- the press travels kglobalaccel, the
    // session daemon, the CLI and the IPC first -- so nothing committed and
    // the switcher stayed on screen. It comes through the daemon now, and it
    // is a property rather than a call because it can arrive before there is
    // anything to receive it: the surface reads it when it opens.
    //
    // Not cleared when the switcher opens, on purpose. The press and the
    // release are two detached processes racing each other through the CLI, so
    // for a quick enough Alt+Tab the release can arrive *first* -- and a
    // choice that was made must not be dropped because the two crossed. It is
    // cleared when the switcher goes away, and honoured only while it is
    // fresh, so a stray one cannot close the next switcher on sight.
    property bool windowSwitcherCommitWanted: false
    property real windowSwitcherCommitAt: 0

    // How long a commit is worth acting on: long enough to cross a process
    // boundary twice, short enough that nobody's next Alt+Tab meets it.
    readonly property int windowSwitcherCommitWindow: 1500

    readonly property bool windowSwitcherCommitFresh: root.windowSwitcherCommitWanted
        && (Date.now() - root.windowSwitcherCommitAt) < root.windowSwitcherCommitWindow

    // What the session screen was opened for: "promptAll", "promptLogout",
    // "promptReboot" or "promptShutDown", as Plasma's prompt names them.
    property string sessionKind: "promptAll"

    // The screen they appear on; empty is the first.
    property string screen: ""

    readonly property string screenName: root.screen.length > 0 ? root.screen : (Quickshell.screens[0]?.name ?? "")

    function _only(which, screen) {
        if (which !== "windowSwitcher")
            root.windowSwitcherCommitWanted = false;
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

    // Asked for by the key coming up. Held as a wish rather than acted on
    // here: this layer does not know which window is selected, and the
    // surface that does may not exist yet.
    function commitWindowSwitcher() {
        root.windowSwitcherCommitAt = Date.now();
        root.windowSwitcherCommitWanted = true;
    }

    function toggleSidebar(screen) { root._only(root.sidebar ? "" : "sidebar", screen); }
    function toggleKeys(screen) { root._only(root.keys ? "" : "keys", screen); }

    function openSession(kind, screen) {
        root.sessionKind = kind ?? "promptAll";
        root._only("session", screen);
    }

    function closeAll() { root._only(""); }
}
