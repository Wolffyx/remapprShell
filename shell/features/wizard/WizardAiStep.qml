// The first-run wizard, step 6 of 7: whether to hand a diagnostic report to
// an assistant when something breaks, and which one.
//
// A step is only what it draws. The window detects the providers, hands them
// in, and holds the answer -- "off" unless one is picked.

import QtQuick
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    property string ai: "off"
    property var aiProviders: []

    signal aiPicked(string value)

    spacing: 6

    SettingRow {
        width: parent.width
        label: "AI assist"
        description: "Hands a redacted diagnostic report to an assistant, on request. Nothing leaves this machine without showing you exactly what would go."
        Select {
            values: ["off"].concat(root.aiProviders)
            currentIndex: Math.max(0, ["off"].concat(root.aiProviders).indexOf(root.ai))
            onPicked: value => root.aiPicked(value)
        }
    }

    // Under the choice it explains. It was drawn a step later, under
    // the theme's switches, where it answered a question nobody had
    // just been asked.
    PanelText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.foregroundInactive
        text: root.aiProviders.length === 0
            ? "No provider was found on this machine. The clipboard one needs wl-copy; claude-code needs the claude command."
            : "The clipboard provider copies the report and sends nothing. The others are named after the program they run, and were found here."
    }
}
