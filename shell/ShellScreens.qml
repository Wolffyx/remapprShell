pragma ComponentBehavior: Bound

// Everything the shell draws on a screen: the panel, the search, the
// sidebar and its handle, the key sheet, the clipboard menu, the session
// screen, both switchers, the desktop's own two, the OSD and the
// notification popups -- each a Variants over the screens it belongs on, so
// a monitor plugged in or taken away is handled the same way for all of them.
//
// Kept in the order they were always made in. Two surfaces on the same layer
// are stacked by the compositor, and the order they were made in can be what
// decides it.

import QtQuick
import Quickshell
import qs.features.panel
import qs.features.panel.model
import qs.domain.launcher
import qs.domain.osd
import qs.domain.config
import qs.features.osd
import qs.features.notifications
import qs.features.switchers
import qs.domain.notifications
import qs.features.launcher
import qs.features.desktop
import qs.features.overlays
import qs.domain.surfaces
import qs.domain.surfaces.place

Scope {
    // One panel per screen. Variants rebuilds the set on monitor hotplug, so
    // nothing here has to watch for display changes.
    //
    // Drawn only when this renderer is the one selected. The Plasma renderer
    // draws the same panel through plasmashell, and both drawing at once is
    // the two-panels-at-one-edge bug the renderer key exists to prevent -- so
    // the check lives here, where the panels are created, rather than in
    // anything that could be forgotten.
    Variants {
        // Not until the profile has been read: the defaults name this shell
        // as what draws the panel, so a profile that names Plasma instead
        // would otherwise get a panel for one frame and then lose it.
        model: ConfigStore.profileLoaded && PanelModel.renderer === "quickshell"
            ? Quickshell.screens : []

        Panel {}
    }

    // The built-in search, over the screen it was opened on -- the first one
    // when it was opened from a key.
    Variants {
        model: LauncherService.builtin.visible && LauncherService.builtin.mode === "search"
            ? Quickshell.screens.filter(s => s.name === (LauncherService.builtin.shownOn || (Quickshell.screens[0]?.name ?? "")))
            : []

        SearchOverlay {}
    }

    // The strip the sidebar is pulled out by, on every screen -- so it comes
    // out of the monitor it was dragged on. `sidebar.trigger` chooses between
    // this, KWin's screen edge, and neither.
    Variants {
        model: ConfigStore.value("sidebar.trigger", "drag") === "drag" ? Quickshell.screens : []
        SidebarHandle {}
    }

    // The sidebar, the key sheet and the session screen: one at a time, on
    // the screen they were asked for on (Surfaces).
    Variants {
        model: Surfaces.sidebar ? Quickshell.screens.filter(s => s.name === Surfaces.screenName) : []
        Sidebar {}
    }

    Variants {
        model: Surfaces.keys ? Quickshell.screens.filter(s => s.name === Surfaces.screenName) : []
        KeysOverlay {}
    }

    // The clipboard history, under the pointer. The screen is whichever one
    // the pointer was on, by the name KWin gave it; by the coordinates when
    // the name did not come through.
    Variants {
        model: Surfaces.clipboard
            ? Quickshell.screens.filter(s => Surfaces.clipboardScreen.length > 0
                                             ? s.name === Surfaces.clipboardScreen
                                             : Place.contains(s, Surfaces.clipboardX, Surfaces.clipboardY)).slice(0, 1)
            : []
        ClipboardOverlay {}
    }

    Variants {
        model: Surfaces.session ? Quickshell.screens.filter(s => s.name === Surfaces.screenName) : []
        SessionOverlay {}
    }

    // Alt+Tab, when `switching.windows` says this shell draws it.
    Variants {
        model: Surfaces.windowSwitcher ? Quickshell.screens.filter(s => s.name === Surfaces.screenName) : []
        WindowSwitcher {}
    }

    // Meta+Tab, when `switching.desktops` says this shell draws it rather than
    // KWin's Overview.
    Variants {
        model: Surfaces.overview ? Quickshell.screens.filter(s => s.name === Surfaces.screenName) : []
        Overview {}
    }

    // The desktop's own two: a rounded frame over the screen's corners, and a
    // clock on the wallpaper. Both off by default, both drawn only where they
    // are asked for, and neither takes a click or reserves a pixel.
    Variants {
        model: ConfigStore.value("desktop.border", false) === true ? Quickshell.screens : []

        ScreenBorder {}
    }

    Variants {
        model: ConfigStore.value("desktop.clock", false) === true ? Quickshell.screens : []

        DesktopClock {}
    }

    // Off unless asked for, and built only then: Plasma's OSD already works,
    // and this exists for someone who wants a layer-shell one instead.
    Variants {
        model: OsdService.enabled ? Quickshell.screens.slice(0, 1) : []

        OsdOverlay {}
    }

    // This shell's own notification popups: only when notifications.server
    // is "shell" and its server really holds the name. Off by default; Plasma
    // draws them otherwise. One screen, as the OSD.
    Variants {
        model: ShellNotifications.active ? Quickshell.screens.slice(0, 1) : []

        NotificationPopups {}
    }
}
