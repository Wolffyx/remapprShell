// The first-run wizard, step 3 of 7: a layout to start from, or the
// configuration there already is.
//
// A step is only what it draws. The window reads the presets from the CLI,
// hands them in, and holds the one picked -- empty for keeping what is there.

import QtQuick
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    property var presets: []

    signal presetPicked(string value)

    spacing: 6

    PanelText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.foregroundInactive
        text: "A layout replaces your current configuration. Your existing one is kept, and 'preset apply' can be undone from the Layouts page."
    }

    SettingRow {
        width: parent.width
        label: "Layout"
        Select {
            values: ["keep what I have"].concat(root.presets)
            currentIndex: 0
            onPicked: value => root.presetPicked(value === "keep what I have" ? "" : value)
        }
    }
}
