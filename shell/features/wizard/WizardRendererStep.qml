// The first-run wizard, step 5 of 7: what draws the panel -- this shell, or
// Plasma's own panel from the same configuration.
//
// A step is only what it draws. The window holds the answer, and at Finish
// runs the command that switches renderer; this says so before it is chosen.

import QtQuick
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    property string renderer: "quickshell"

    signal rendererPicked(string value)

    spacing: 6

    SettingRow {
        width: parent.width
        label: "Drawn by"
        description: "Plasma's panel is drawn from this same configuration, but with stock applets only."
        Select {
            values: ["quickshell", "plasma"]
            currentIndex: root.renderer === "plasma" ? 1 : 0
            onPicked: value => root.rendererPicked(value)
        }
    }

    PanelText {
        visible: root.renderer !== "quickshell"
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.foregroundInactive
        text: "This one changes KDE's own settings. A restore point is taken first, and it is put back automatically if the switch does not work."
    }
}
