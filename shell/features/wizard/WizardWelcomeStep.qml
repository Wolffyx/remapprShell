// The first-run wizard, step 1 of 7: what this shell is and is not, and the
// promise that nothing is written until the last step.
//
// A step is only what it draws. The window hosts it, shows it when it is its
// turn, and holds every answer -- this one asks nothing.

import QtQuick
import qs.core
import qs.domain.theme
import qs.ui.primitives

Column {
    id: root

    spacing: 8

    PanelText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: `${Branding.displayName} draws a panel and rethemes Plasma's own components. It does not replace your notifications, lock screen, wallpaper or task switcher -- Plasma already has those, and they keep working.`
    }

    PanelText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.foregroundInactive
        text: "Nothing is written until the last step, and everything here can be changed afterwards in settings."
    }
}
