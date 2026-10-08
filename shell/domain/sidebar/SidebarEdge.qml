// Keeps KWin's screen edges agreeing with the sidebar's own settings.
//
// The edge on the sidebar's side is the sidebar's: pushed into, it opens it
// (`sidebar.trigger` "hover") or lights the grab strip to be pulled ("drag",
// the default -- SidebarHandle, SidebarReveal). Which edge does what lives in
// kwinrc, inside our own KWin script, not in the shell's configuration -- so
// moving the sidebar to the other side, or changing how it is opened, would
// otherwise leave the edge as it was.
//
// The decision is here; the writing is the CLI's, exactly as DesktopVariant
// does it for light and dark. `edges follow` binds, moves or frees the one
// edge, and leaves every other edge alone -- and is told the three settings
// rather than reading them: they change here the moment they are set, and
// reach the file a quarter of a second later (ConfigStore's write timer), so
// a CLI that read the file bound the edge for the setting before. Choosing
// "Pointer at the edge" left the strip's edge bound, and choosing the strip
// again then bound the hover edge -- one setting behind, every time.

import QtQuick
import qs.platform.system
import qs.domain.config

QtObject {
    id: root

    readonly property string side: ConfigStore.value("sidebar.position", "right") === "left" ? "left" : "right"
    readonly property string trigger: ConfigStore.value("sidebar.trigger", "drag")
    readonly property bool reserves: ConfigStore.value("sidebar.handleReserves", false) === true

    // Both settings decide it: which side the sidebar is on, and whether an
    // edge opens it at all -- the strip you pull (the default) and a hover
    // edge are two answers to the same question, and having both is how a
    // sidebar opens by accident.
    readonly property string position: ConfigStore.profileLoaded
        ? `${root.side}/${root.trigger}/${root.reserves}` : ""

    // What was last asked for, so a setting written twice over is asked
    // about once.
    property string asked: ""

    // The first value seen is asked about too: the grab strip is lit by an
    // edge (sidebar.trigger "drag", the default), so a shell that starts with
    // no edge bound -- a first start, an edge given back by hand -- would
    // have a strip nothing can light. `follow` is a no-op when it matches.
    onPositionChanged: {
        if (root.position.length === 0 || root.position === root.asked)
            return;
        root.asked = root.position;
        follow.run(["edges", "follow", root.side, root.trigger, String(root.reserves)]);
    }

    readonly property CtlRun _follow: CtlRun {
        id: follow
        tag: "sidebar"
        label: `edges follow, for a sidebar at ${root.position}`
    }
}
