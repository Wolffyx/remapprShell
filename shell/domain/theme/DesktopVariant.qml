// Keeps the applications' light and dark with the shell's.
//
// `theme.mode: auto` turns the shell light by day and dark by night, on KWin's
// Night Light schedule. The applications read KDE's own configuration -- the
// colour scheme and the icon theme -- which the shell does not draw and cannot
// bind to, so they stayed wherever `theme apply` last put them and a light
// shell sat on a dark desktop until somebody ran a command.
//
// Following it means writing KDE keys when night falls, which is not something
// to do to a desktop uninvited: `theme.desktop.followMode` is off by default,
// and `rmpr theme variant` does the same thing once, by hand.
//
// There is a second reason to run, and it needs no permission. Plasma has a
// day/night switch of its own -- "Switch to Dark Mode at Night" -- and when it
// is on it swaps the whole global theme at sunset. What it cannot swap is
// GTK's theme and its dark preference, which live in gsettings, or our Plasma
// desktop theme, whose colours are generated per variant. Those are the gaps,
// and the command fills only those when Plasma is the one switching. So the
// trigger runs whenever anything switches -- Plasma or us -- and what it does
// depends on which.
//
// The writing itself belongs to the CLI, not here. `theme variant` ledgers
// every key it touches so `theme revert` can put the desktop back, and a
// second implementation of that in QML is exactly the sort of thing that
// drifts -- so this decides *when*, and the script decides *what*.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.config

QtObject {
    id: root

    // Whether anything needs doing when the mode changes. Theming the desktop
    // at all is the first switch. After that, either the user asked us to
    // follow the schedule, or Plasma is following it itself and has left the
    // gaps for us -- the script decides which of the two it is looking at, and
    // writes accordingly.
    readonly property bool following: ConfigStore.profileLoaded
        && ConfigStore.value("theme.desktop.enabled", true) === true
        && (ConfigStore.value("theme.desktop.followMode", false) === true
            || PlasmaColors.automaticLookAndFeel)

    // What the shell is in. Not the setting: `auto` is answered by Night Light
    // and by the Plasma scheme's own darkness, and this must follow the answer.
    readonly property string variant: Theme.mode

    // The last variant this shell asked for, so a config write that changes
    // nothing does not run the command again. The script checks too -- it is
    // called on every start -- but a shell that asks once is cheaper than a
    // script that declines.
    property string asked: ""

    onFollowingChanged: if (root.following) root._schedule();
    onVariantChanged: if (root.following) root._schedule();

    // Turning Plasma's switch on hands the schedule over mid-session, and the
    // mode string does not change when it happens. Without this the gaps stay
    // unfilled until the next sunset.
    readonly property bool _plasmaSwitches: PlasmaColors.automaticLookAndFeel
    on_PlasmaSwitchesChanged: if (root.following) {
        root.asked = "";
        root._schedule();
    }

    function _schedule(): void {
        if (root.variant !== root.asked)
            debounce.restart();
    }

    // Night falls once; a colour scheme write arrives several times, and
    // `theme.mode` can resolve twice at startup -- once on the colour scheme,
    // again when Night Light answers. One second of quiet is enough to ask
    // only for the answer.
    readonly property Timer _debounce: Timer {
        id: debounce
        interval: 1000
        onTriggered: {
            if (!root.following || root.variant === root.asked)
                return;
            root.asked = root.variant;
            apply.running = false;
            apply.command = [Branding.ctlBin, "theme", "variant", root.variant, "--if-following"];
            apply.running = true;
            Log.info("theme", `putting the desktop in ${root.variant}`);
        }
    }

    readonly property Process _apply: Process {
        id: apply
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0)
                Log.warn("theme", `theme variant: ${text.trim().split("\n").pop()}`)
        }
        onExited: (code, status) => {
            if (code !== 0)
                Log.warn("theme", `theme variant ${root.asked} exited ${code}`);
        }
    }
}
