// Keeps KWin's screen edges agreeing with the sidebar's own settings.
//
// The sidebar can be opened by pushing the pointer into an edge (`rmpr edges
// shell Right sidebar`), and which edge that is lives in kwinrc, inside our
// own KWin script -- not in the shell's configuration. So moving the sidebar
// to the other side would otherwise leave the edge where it was, and pushing
// right would open a panel on the left.
//
// The decision is here; the writing is the CLI's, exactly as DesktopVariant
// does it for light and dark. `edges follow` reads the setting, finds the edge
// bound to the sidebar, and moves it -- and does nothing when no edge is bound
// to the sidebar at all, which is the common case. Nothing is bound on our
// behalf: an edge is the user's to give.

import QtQuick
import qs.platform.system
import qs.domain.config

QtObject {
    id: root

    // Both settings decide it: which side the sidebar is on, and whether an
    // edge opens it at all -- the strip you pull (the default) and a hover
    // edge are two answers to the same question, and having both is how a
    // sidebar opens by accident.
    readonly property string position: ConfigStore.profileLoaded
        ? `${ConfigStore.value("sidebar.position", "right")}/${ConfigStore.value("sidebar.trigger", "drag")}` : ""

    // What was last asked for, so the start of the shell -- which is a change
    // from "" to the setting -- does not run the command for nothing.
    property string asked: ""

    onPositionChanged: {
        if (root.position.length === 0 || root.position === root.asked)
            return;
        // The first value seen is the one the shell started with, and the
        // edge already matches it or the user has chosen otherwise.
        if (root.asked.length === 0) {
            root.asked = root.position;
            return;
        }
        root.asked = root.position;
        follow.run(["edges", "follow"]);
    }

    readonly property CtlRun _follow: CtlRun {
        id: follow
        tag: "sidebar"
        label: `edges follow, for a sidebar at ${root.position}`
    }
}
