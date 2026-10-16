pragma Singleton

// The layer-shell namespace the shell's own chrome gives KWin.
//
// KWin types a layer surface by its namespace and by nothing else
// (layershellv1window.cpp, scopeToType): "dock" is a Dock, "desktop" a
// Desktop, a few other names their own types, and any other name -- the
// "quickshell" Quickshell gives a surface that names none, or one of ours --
// a Normal window. Show Desktop treats a Normal window as an application's
// (workspace.cpp, breaksShowingDesktop): it hides it, and one that maps or is
// activated while the desktop is showing turns Show Desktop off.
//
// So Meta+D took the panel away with the windows, and the panel's own
// show-desktop strip showed the desktop for five to eight milliseconds before
// KWin put the windows back by itself -- measured with dbus-monitor on
// 2026-10-16: showDesktop(true) from the strip, showingDesktopChanged true,
// then false, with no second call from anyone (#15).
//
// What belongs to the panel or the desktop is a dock: the panel, its popouts,
// tooltips and menu, the surface that closes them, the sidebar's grip, the
// screen's border and the desktop clock. KWin then leaves them on screen while
// the desktop shows and never counts them as a window coming back. What a
// person opens -- the launcher, a switcher, the sidebar, the clipboard -- keeps
// a name of its own and is a window, as KRunner is: opening one while the
// desktop shows brings the windows back, in Plasma as well.

import QtQuick

QtObject {
    readonly property string chrome: "dock"
}
