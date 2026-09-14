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

    // The switcher's key let go, as the session daemon heard it.
    //
    // This exists for one case only: a quick Alt+Tab, where the key is
    // released before the surface is mapped. The press travels kglobalaccel,
    // the daemon, the CLI and the IPC first, so the surface's own key handling
    // -- which is what commits every other time -- has nothing to receive the
    // release, and the switcher stayed on screen with the key already up.
    //
    // The surface reads this when it opens and never again, because what
    // kglobalaccel reports is the release of the *shortcut*: Tab coming up,
    // not Alt. Acting on it while the switcher is up closed it on the first
    // Tab, so holding Alt and stepping through the list was impossible.
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

    // When the switcher last closed.
    //
    // Every tap of Tab spawns an open of its own through the CLI, so the last
    // one can still be in flight when the modifier comes up and the choice is
    // made. Arriving after that, it opened a switcher with no key held and
    // nothing to close it -- which is what "the overlay stays open after
    // switching" was. An open that lands just behind a close belongs to the
    // burst that ended in it, so it is dropped.
    property real windowSwitcherCommittedAt: 0

    readonly property int windowSwitcherReopenGuard: 600

    // What the session screen was opened for: "promptAll", "promptLogout",
    // "promptReboot" or "promptShutDown", as Plasma's prompt names them.
    property string sessionKind: "promptAll"

    // The screen they appear on; empty is the first.
    property string screen: ""

    readonly property string screenName: root.screen.length > 0 ? root.screen : (Quickshell.screens[0]?.name ?? "")

    function _only(which, screen) {
        if (which !== "windowSwitcher") {
            root.windowSwitcherCommitWanted = false;
            // However it went away -- a choice, Escape, a click outside -- an
            // open still travelling the CLI from the last tap of Tab must not
            // bring it back behind whatever just closed it.
            if (root.windowSwitcher)
                root.windowSwitcherCommittedAt = Date.now();
        }
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
        if (!root.windowSwitcher
            && (Date.now() - root.windowSwitcherCommittedAt) < root.windowSwitcherReopenGuard)
            return;
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
