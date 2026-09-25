// The first-run wizard, step 4 of 7: which menu the start button opens.
//
// A step is only what it draws. The window holds the answer, hands it in,
// and takes the new one from the signal.

import QtQuick
import qs.ui.controls

Column {
    id: root

    property string launcher: "builtin"

    signal launcherPicked(string value)

    spacing: 6

    SettingRow {
        width: parent.width
        label: "Application menu"
        description: "Kickoff is Plasma's own menu. The built-in one is ours. Either can be changed later."
        Select {
            values: ["auto", "kickoff", "builtin", "krunner"]
            currentIndex: Math.max(0, ["auto", "kickoff", "builtin", "krunner"].indexOf(root.launcher))
            onPicked: value => root.launcherPicked(value)
        }
    }
}
