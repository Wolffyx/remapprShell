// The first-run wizard, step 1 of 7: what this shell is and is not, whether
// each answer shows on the desktop as it is given, and the promise that
// nothing is saved until the last step.
//
// A step is only what it draws. The window hosts it, shows it when it is its
// turn, and holds every answer -- the one asked here included.

import QtQuick
import qs.core
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    property bool live: true

    signal livePicked(bool value)

    spacing: 8

    PanelText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: `${Branding.displayName} draws a panel and rethemes Plasma's own components. It does not replace your notifications, lock screen, wallpaper or task switcher -- Plasma already has those, and they keep working.`
    }

    ToggleRow {
        label: "Show each choice as I make it"
        description: "The panel moves as you pick. Off, nothing changes until Finish."
        checked: root.live
        onToggled: value => root.livePicked(value)
    }

    PanelText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.foregroundInactive
        text: root.live
            ? "Nothing is saved until the last step: close this and everything goes back. Everything here can be changed afterwards in settings."
            : "Nothing is written until the last step, and everything here can be changed afterwards in settings."
    }
}
