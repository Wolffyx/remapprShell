pragma ComponentBehavior: Bound

// Appearance: what this shell's theme is allowed to change outside itself --
// the whole desktop or only the shell, and then part by part, GTK included.
//
// A card of the appearance page, apart from it so the page reads as the list
// of its cards. Every row writes a `theme.desktop.` key. What it cannot know
// by itself -- which GTK themes are installed, and whether
// kde-material-you-colors is -- the page reads from `theme status` and hands
// it in.

import QtQuick
import qs.domain.config
import qs.ui.primitives
import qs.ui.controls

Card {
    id: root

    // From the page's `theme status`: the GTK themes installed, which the two
    // pickers offer, and whether kde-material-you-colors is there to be told.
    property var gtkThemes: []
    property bool materialYouInstalled: false

    spacing: 2

    // What the theme is allowed to touch.
    //
    // The parts are the schema's, and the same names the CLI prints, so a
    // checkbox here and `theme status` can never describe different things.
    // Each one off keeps whatever System Settings says for it.
    SectionLabel { text: "What it themes" }

    ConfigToggleRow {
        label: "Theme the whole desktop"
        description: "Applications match the shell, rather than only the panel and its popouts."
        path: "theme.desktop.enabled"
    }

    Column {
        width: parent.width
        spacing: 6
        opacity: ConfigStore.value("theme.desktop.enabled", true) === true ? 1 : 0.45
        enabled: ConfigStore.value("theme.desktop.enabled", true) === true

        // Off by default, and not one of the parts: the parts say what an
        // apply writes once, this says the colours are rewritten again
        // every time night falls.
        ConfigToggleRow {
            label: "Applications follow day and night"
            description: "With Colour scheme on auto, KDE's colour scheme and icons turn dark with the shell. Plasma's own widgets follow from the next start."
            path: "theme.desktop.followMode"
        }

        // Not about who switches, but about noticing when the one who was
        // supposed to did not. Plasma's switch missed a sunset on
        // 2026-09-22 and the desktop stayed light behind a dark shell all
        // evening.
        ConfigToggleRow {
            label: "Fix day and night when Plasma forgets"
            description: "Plasma's own \"Switch to Dark Mode at Night\" runs on a timer, and a timer can miss. When it does, the desktop is put in the right half here -- after twenty seconds' grace, so the two never write over each other."
            path: "theme.desktop.rescuePlasmaSwitch"
        }

        Repeater {
            model: [
                { key: "colours",     label: "Colour scheme",        sub: "The colours every Qt application is drawn with." },
                { key: "icons",       label: "Icon theme",           sub: "Applications, and the shell's own icons, which come from the theme." },
                { key: "style",       label: "Widget style",         sub: "Buttons, scrollbars, checkboxes." },
                { key: "plasmaTheme", label: "Plasma desktop theme", sub: "Plasma's own surfaces, and anything this shell does not draw." },
                { key: "decorations", label: "Window decorations",   sub: "The titlebars and borders KWin draws." },
                { key: "switcher",    label: "Alt+Tab switcher",     sub: "The window switcher's layout." }
            ]

            delegate: ConfigToggleRow {
                required property var modelData
                label: modelData.label
                description: modelData.sub
                path: `theme.desktop.${modelData.key}`
            }
        }

        ConfigToggleRow {
            label: "GTK applications"
            description: "Chrome, Electron and GTK applications ask GTK whether to be dark, not KDE. With this on they are told too."
            path: "theme.desktop.gtk"
        }

        // A theme whose name is the dark half of a pair stays dark whatever
        // GTK is asked to prefer, so the pair is named, one per variant.
        // From what is installed, because a mistyped name is a theme GTK
        // silently does not find.
        Repeater {
            model: [
                { key: "gtkThemeLight", label: "GTK theme by day" },
                { key: "gtkThemeDark",  label: "GTK theme by night" }
            ]

            delegate: SettingRow {
                id: gtkRow
                required property var modelData
                readonly property string path: `theme.desktop.${modelData.key}`
                readonly property string current: ConfigStore.value(gtkRow.path, "") ?? ""
                // Something set that is not installed is still shown, as itself.
                readonly property var names: [""].concat(root.gtkThemes.indexOf(gtkRow.current) >= 0 || gtkRow.current === ""
                    ? root.gtkThemes : root.gtkThemes.concat([gtkRow.current]))

                visible: ConfigStore.value("theme.desktop.gtk", true) === true
                width: parent.width
                label: modelData.label
                description: gtkRow.current === "" ? "Left as it is." : ""
                overridden: ConfigStore.isOverridden(gtkRow.path)
                onResetRequested: ConfigStore.reset(gtkRow.path)

                Select {
                    values: gtkRow.names
                    labels: gtkRow.names.map(n => n === "" ? "Leave it alone" : n)
                    currentIndex: Math.max(0, gtkRow.names.indexOf(gtkRow.current))
                    onPicked: value => ConfigStore.set(gtkRow.path, value)
                }
            }
        }

        ConfigToggleRow {
            visible: root.materialYouInstalled
            label: "kde-material-you-colors"
            description: "It has a light and dark switch of its own and applies it at every login. With this on it is told which one, so the two agree."
            path: "theme.desktop.materialYou"
        }
    }
}
