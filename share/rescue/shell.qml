// The rescue window: what is drawn when the shell itself could not start.
//
// Opened by scripts/rescue.sh -- `rescue --if-given-up`, from the report unit
// systemd starts when the shell's unit fails -- in a unit of its own, as a
// Quickshell config of its own. While the shell is down nothing serves
// notifications, so a window is the one way left to say so (2026-10-08).
//
// It imports nothing from the shell's tree and spells no name: the tree is
// what failed, and everything this says arrives in the environment rescue.sh
// sets for it.

import QtQuick
import Quickshell

ShellRoot {
    FloatingWindow {
        title: panel.name !== "" ? `${panel.name} couldn't start` : "The shell couldn't start"
        implicitWidth: 620
        implicitHeight: panel.implicitHeight
        color: panel.surface
        visible: true

        RescuePanel {
            id: panel
            anchors.fill: parent
            name: Quickshell.env("RESCUE_NAME") ?? ""
            unit: Quickshell.env("RESCUE_UNIT") ?? ""
            errors: Quickshell.env("RESCUE_ERRORS") ?? ""
            report: Quickshell.env("RESCUE_REPORT") ?? ""
            hint: Quickshell.env("RESCUE_HINT") ?? ""
            onDone: Qt.quit()
        }
    }
}
