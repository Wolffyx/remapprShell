pragma ComponentBehavior: Bound

// What the start menu's search found, a row each -- or a line saying it found
// nothing.
//
// Not called Results: qs.domain.launcher.apps has a Results already -- the
// arithmetic that puts this list together -- and in the layouts, which
// import it, a file of the same name here would collide with it.

import QtQuick
import qs.domain.launcher.providers
import qs.domain.theme
import qs.ui.primitives

Column {
    id: results

    required property BuiltinProvider provider

    spacing: 2

    Repeater {
        model: results.provider.results
        ResultRow { provider: results.provider }
    }

    PanelText {
        visible: results.provider.results.length === 0
        topPadding: 8
        leftPadding: 12
        text: "No matches"
        color: Theme.mut
    }
}
