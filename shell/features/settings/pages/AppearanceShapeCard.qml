pragma ComponentBehavior: Bound

// Appearance: the shape card -- corner rounding, how long things take to
// appear, translucency and shadows, and which fonts the shell found.
//
// A card of the appearance page, apart from it so the page reads as the list
// of its cards. Every control writes one `theme.` key, and it needs nothing of
// the page's but a width.

import QtQuick
import qs.domain.config
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Card {
    id: root

    spacing: 6

    SectionLabel { text: "Shape" }

    Row {
        width: parent.width
        PanelText { text: "Corner rounding"; font.pixelSize: 14; width: parent.width - roundingValue.width }
        PanelText { id: roundingValue; text: `${Theme.rounding} px`; color: Theme.mut }
    }

    NumberSlider {
        width: parent.width
        showReadout: false
        from: 0
        to: 36
        stepSize: 2
        value: Theme.rounding
        onMoved: value => ConfigStore.set("theme.rounding", Math.round(value))
    }

    // One speed for every surface that appears: a popout rising out of the
    // panel, the switcher, the overview.
    Row {
        width: parent.width
        PanelText { text: "How long things take to appear"; font.pixelSize: 14; width: parent.width - animValue.width }
        PanelText {
            id: animValue
            text: Theme.animationMs === 0 ? "at once" : `${Theme.animationMs} ms`
            color: Theme.mut
        }
    }

    NumberSlider {
        width: parent.width
        showReadout: false
        from: 0
        to: 400
        stepSize: 20
        value: Theme.animationMs
        onMoved: value => ConfigStore.set("theme.animationMs", Math.round(value))
    }

    ToggleRow {
        width: parent.width
        label: "Translucent surfaces"
        description: "The panel and its popouts let a little of the wallpaper through."
        checked: Theme.translucent
        onToggled: value => ConfigStore.set("theme.translucent", value)
    }

    ToggleRow {
        width: parent.width
        label: "Drop shadows"
        description: "Under the panel, its popouts, the start menu and the on-screen display. Off by default: a shadow is a band of dimmed wallpaper around a surface whose own background is blurred, and the join between the two can read as a second panel behind the first."
        checked: Theme.shadows
        onToggled: value => ConfigStore.set("theme.shadows", value)
    }

    Hint {
        text: `Type: ${Theme.fontFamily}${Theme.fontFamily === "Rubik" ? "" : " (Rubik is not installed)"} · icons: ${Theme.hasIconFont ? Theme.iconFont : "the icon theme (Material Symbols Rounded is not installed)"}`
        lineHeight: 1
    }
}
