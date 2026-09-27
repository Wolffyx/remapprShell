pragma ComponentBehavior: Bound

// The first-run wizard, step 7 of 7: what this shell's theme may change
// outside itself -- the whole desktop or only the shell, and then part by
// part.
//
// A step is only what it draws. The window holds the parts and the answers,
// hands them in, and takes each switch from a signal -- nothing is written
// here, or until Finish.

import QtQuick
import qs.core
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    property bool themeDesktop: true
    // [{ key, label, sub }], and which of them are wanted, by key.
    property var themeParts: []
    property var themeWanted: ({})

    signal themeDesktopToggled(bool value)
    signal partToggled(string key, bool value)

    spacing: 6

    PanelText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: `Choosing ${Branding.displayName}'s theme can retheme KDE itself, so applications match the shell rather than only the panel. Every key is recorded, and \`${Branding.shortName} theme revert\` puts all of it back.`
    }

    ToggleRow {
        label: "Theme the whole desktop"
        description: "Off confines the theme to what this shell draws."
        checked: root.themeDesktop
        onToggled: value => root.themeDesktopToggled(value)
    }

    Column {
        width: parent.width
        opacity: root.themeDesktop ? 1 : 0.45
        enabled: root.themeDesktop

        Repeater {
            model: root.themeParts

            delegate: ToggleRow {
                required property var modelData
                label: modelData.label
                description: modelData.sub
                checked: root.themeWanted[modelData.key] !== false
                onToggled: value => root.partToggled(modelData.key, value)
            }
        }
    }
}
