pragma ComponentBehavior: Bound

// Appearance: the Qt style applications are drawn in, and which parts of this
// shell's own theme are installed.
//
// Both go through `theme`, the command the CLI has. A style is a single
// ledgered key with an undo of its own. Installing the theme's parts runs a
// plain `theme apply`, which takes a restore point first and changes no
// colours, icons or style -- that is `--appearance`, and this page does not
// offer it. A style that is not installed is shown with the command that
// installs it, for a person to run: nothing here installs a package.

import QtQuick
import qs.core
import qs.platform.kde
import qs.platform.system
import qs.domain.config
import qs.domain.theme
import qs.domain.theme.palette
import qs.ui.primitives
import qs.ui.controls

CardGrid {
    id: root

    // `theme status --json`, and the command that changes it.
    readonly property CtlSession ctl: CtlSession {
        prefix: ["theme"]
        readFailed: "Could not read the theme's state."
    }
    readonly property var themeState: root.ctl.state

    readonly property var styles: root.themeState?.styles ?? []
    readonly property var parts: root.themeState?.parts ?? ({})
    readonly property var gtkThemes: root.themeState?.gtkThemes ?? []
    readonly property bool materialYouInstalled: root.themeState?.materialYouInstalled === true

    // The parts a plain apply would add, named as a person would.
    readonly property var missing: {
        if (!root.themeState)
            return [];
        const out = [];
        if (!root.themeState.package)
            out.push("the look-and-feel package");
        if ((root.parts.schemes ?? 0) === 0)
            out.push("the colour schemes");
        if (!root.parts.switcher)
            out.push("the Alt+Tab switcher");
        if (!root.parts.desktoptheme)
            out.push("the Plasma theme");
        if (!root.parts.splash)
            out.push("the splash");
        return out;
    }

    count: 7

    Component.onCompleted: root.ctl.refresh()

    Card {
        id: scheme

        width: root.width
        spacing: 12

        SectionLabel { text: "Colour scheme" }

        Row {
            id: modes
            width: parent.width
            spacing: 12

            Repeater {
                model: [
                    { id: "auto", label: "Auto", sub: "Follows Plasma" },
                    { id: "light", label: "Light", sub: "Always light" },
                    { id: "dark", label: "Dark", sub: "Always dark" }
                ]

                Rectangle {
                    id: modeCard

                    required property var modelData
                    readonly property bool chosen: Theme.modeSetting === modeCard.modelData.id
                    readonly property var light: Scheme.scheme(Theme.seed, false)
                    readonly property var dark: Scheme.scheme(Theme.seed, true)

                    width: (modes.width - 2 * modes.spacing) / 3
                    height: 112
                    radius: Theme.radiusSmall + 2
                    color: modeCard.chosen ? Theme.accC : (modeHover.hovered ? Theme.s3 : Theme.s2)
                    border.width: 1
                    border.color: modeCard.chosen ? Theme.acc : Theme.out

                    // A picture of the scheme, in the scheme's own colours: the
                    // automatic one is half of each.
                    Rectangle {
                        id: swatch
                        x: 14; y: 14
                        width: parent.width - 28
                        height: 50
                        radius: 10
                        clip: true
                        color: "transparent"

                        Row {
                            anchors.fill: parent

                            Repeater {
                                model: modeCard.modelData.id === "auto" ? [modeCard.light, modeCard.dark]
                                     : [modeCard.modelData.id === "dark" ? modeCard.dark : modeCard.light]

                                Rectangle {
                                    id: half

                                    required property var modelData

                                    width: swatch.width / (modeCard.modelData.id === "auto" ? 2 : 1)
                                    height: swatch.height
                                    color: half.modelData.surfaceContainerLow

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        Rectangle { width: 22; height: 22; radius: 11; color: half.modelData.primary }
                                        Rectangle { width: 38; height: 22; radius: 11; color: half.modelData.surfaceContainerHighest }
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        x: 14
                        anchors.top: swatch.bottom
                        anchors.topMargin: 10
                        spacing: 1

                        PanelText {
                            text: modeCard.modelData.label
                            font.pixelSize: 14
                            color: modeCard.chosen ? Theme.accCFg : Theme.fg
                        }
                        PanelText {
                            text: modeCard.modelData.sub
                            font.pixelSize: 12
                            color: modeCard.chosen ? Theme.accCFg : Theme.mut
                        }
                    }

                    HoverHandler { id: modeHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: ConfigStore.set("theme.mode", modeCard.modelData.id) }
                }
            }
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            text: {
                const now = `The shell is ${Theme.mode} now`;
                if (Theme.modeSetting !== "auto")
                    return `${now}, whatever Plasma does.`;
                const plasma = PlasmaColors.loaded ? `, because Plasma's colour scheme is ${Scheme.isDark(PlasmaColors.background.toString()) ? "dark" : "light"}` : "";
                return PlasmaColors.automaticLookAndFeel
                    ? `${now}${plasma}. Plasma switches between its light and dark theme by itself, and the shell follows it.`
                    : `${now}${plasma}. Plasma can also switch between a light and a dark theme by itself at sunset, and the shell will follow it: that is in Plasma's global theme settings.`;
            }
        }

        TextButton {
            glyph: "routine"
            iconName: "preferences-desktop-theme-global"
            text: "Plasma's global theme settings"
            onActivated: PlasmaApplets.openSettings("kcm_lookandfeel")
        }

    }

    Card {
        id: accentCard

        width: root.cellWidth
        spacing: 12

        SectionLabel { text: "Accent" }

        Row {
            spacing: 16

            Repeater {
                model: [
                    { id: "plasma", label: "Plasma" },
                    { id: "blue", label: "Blue" },
                    { id: "teal", label: "Teal" },
                    { id: "magenta", label: "Magenta" },
                    { id: "orange", label: "Orange" }
                ]

                Column {
                    id: accentChoice

                    required property var modelData
                    readonly property bool chosen: Theme.accentSetting === accentChoice.modelData.id

                    spacing: 6

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44
                        height: 44
                        radius: 22
                        color: "transparent"
                        border.width: accentChoice.chosen ? 2 : 0
                        border.color: Theme.fg

                        Rectangle {
                            anchors.centerIn: parent
                            width: 36
                            height: 36
                            radius: 18
                            color: Scheme.scheme(Scheme.seed(accentChoice.modelData.id, PlasmaColors.accent.toString()), Theme.dark).primary

                            Glyph {
                                anchors.centerIn: parent
                                visible: accentChoice.modelData.id === "plasma"
                                name: "wallpaper"
                                size: 18
                                color: Scheme.scheme(Scheme.seed("plasma", PlasmaColors.accent.toString()), Theme.dark).onPrimary
                            }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: ConfigStore.set("theme.accent", accentChoice.modelData.id) }
                    }

                    PanelText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: accentChoice.modelData.label
                        font.pixelSize: 12
                        color: accentChoice.chosen ? Theme.fg : Theme.mut
                    }
                }
            }
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            text: "Plasma is Plasma's own accent colour -- which System Settings can take from the wallpaper. Every other colour here is worked out from the accent, in Material Design's roles."
        }

    }

    Card {
        id: shapeCard

        width: root.cellWidth
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

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            color: Theme.mut
            text: `Type: ${Theme.fontFamily}${Theme.fontFamily === "Rubik" ? "" : " (Rubik is not installed)"} · icons: ${Theme.hasIconFont ? Theme.iconFont : "the icon theme (Material Symbols Rounded is not installed)"}`
        }
    }

    Card {
        id: styleCard

        width: root.cellWidth
        spacing: 10

        SectionLabel { text: "Application style" }

        Flow {
            width: parent.width
            spacing: 6
            enabled: !root.ctl.busy

            Repeater {
                model: root.styles

                TextButton {
                    required property var modelData

                    text: modelData.key.charAt(0).toUpperCase() + modelData.key.slice(1)
                    checked: modelData.id === (root.themeState?.style ?? "")
                    enabled: modelData.installed
                    opacity: modelData.installed ? 1 : 0.45
                    onActivated: if (!checked) root.ctl.run(["style", modelData.id])
                }
            }
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            text: {
                const s = root.styles.find(x => x.id === root.themeState?.style);
                const what = s ? `${s.key}: ${s.label}. ` : "";
                return `${what}KDE applications already open change at once; others when next started.`;
            }
        }

        Repeater {
            model: root.styles.filter(s => !s.installed)

            PanelText {
                required property var modelData

                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.mut
                font.pixelSize: 12
                text: modelData.install.length > 0
                    ? `${modelData.key} is not installed. In a terminal: ${modelData.install}`
                    : `${modelData.key} is not installed.`
            }
        }

    }

    Card {
        id: themeCard

        width: root.cellWidth
        spacing: 10

        SectionLabel { text: "This shell's theme" }

        PanelText {
            text: `${Branding.displayName}'s theme`
            font.pixelSize: 13
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            text: {
                if (!root.themeState)
                    return "";
                const state = root.themeState.active ? "Its look-and-feel package is active."
                            : root.themeState.package ? "Its look-and-feel package is installed but not active."
                            : "Not installed.";
                const gaps = root.missing.length > 0 ? ` Missing: ${root.missing.join(", ")}.` : " Every part is installed.";
                return state + gaps;
            }
        }

        TextButton {
            enabled: !root.ctl.busy
            iconName: "run-install"
            text: root.missing.length > 0
                  ? (root.themeState?.package ? "Install the missing parts and apply" : "Install the theme")
                  : "Apply the theme"
            onActivated: root.ctl.run(["apply"])
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            text: "A restore point is taken first, and every key is recorded, so \"Undo everything\" puts the desktop back exactly as it was."
        }
    }

    Card {
        id: parts

        width: root.width
        spacing: 2

        // What the theme is allowed to touch.
        //
        // The parts are the schema's, and the same names the CLI prints, so a
        // checkbox here and `theme status` can never describe different things.
        // Each one off keeps whatever System Settings says for it.
        SectionLabel { text: "What it themes" }

        ToggleRow {
            label: "Theme the whole desktop"
            description: "Applications match the shell, rather than only the panel and its popouts."
            checked: ConfigStore.value("theme.desktop.enabled", true) === true
            onToggled: value => ConfigStore.set("theme.desktop.enabled", value)
        }

        Column {
            width: parent.width
            spacing: 6
            opacity: ConfigStore.value("theme.desktop.enabled", true) === true ? 1 : 0.45
            enabled: ConfigStore.value("theme.desktop.enabled", true) === true

            // Off by default, and not one of the parts: the parts say what an
            // apply writes once, this says the colours are rewritten again
            // every time night falls.
            ToggleRow {
                label: "Applications follow day and night"
                description: "With Colour scheme on auto, KDE's colour scheme and icons turn dark with the shell. Plasma's own widgets follow from the next start."
                checked: ConfigStore.value("theme.desktop.followMode", false) === true
                onToggled: value => ConfigStore.set("theme.desktop.followMode", value)
            }

            // Not about who switches, but about noticing when the one who was
            // supposed to did not. Plasma's switch missed a sunset on
            // 2026-09-22 and the desktop stayed light behind a dark shell all
            // evening.
            ToggleRow {
                label: "Fix day and night when Plasma forgets"
                description: "Plasma's own \"Switch to Dark Mode at Night\" runs on a timer, and a timer can miss. When it does, the desktop is put in the right half here -- after twenty seconds' grace, so the two never write over each other."
                checked: ConfigStore.value("theme.desktop.rescuePlasmaSwitch", true) === true
                onToggled: value => ConfigStore.set("theme.desktop.rescuePlasmaSwitch", value)
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

                delegate: ToggleRow {
                    required property var modelData
                    label: modelData.label
                    description: modelData.sub
                    checked: ConfigStore.value(`theme.desktop.${modelData.key}`, true) === true
                    onToggled: value => ConfigStore.set(`theme.desktop.${modelData.key}`, value)
                }
            }

            ToggleRow {
                label: "GTK applications"
                description: "Chrome, Electron and GTK applications ask GTK whether to be dark, not KDE. With this on they are told too."
                checked: ConfigStore.value("theme.desktop.gtk", true) === true
                onToggled: value => ConfigStore.set("theme.desktop.gtk", value)
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

            ToggleRow {
                visible: root.materialYouInstalled
                label: "kde-material-you-colors"
                description: "It has a light and dark switch of its own and applies it at every login. With this on it is told which one, so the two agree."
                checked: ConfigStore.value("theme.desktop.materialYou", false) === true
                onToggled: value => ConfigStore.set("theme.desktop.materialYou", value)
            }
        }

    }

    Card {
        id: rest

        width: root.cellWidth
        spacing: 12

        SectionLabel { text: "Undo, and the rest" }

        UndoFooter {
            spacing: rest.spacing
            session: root.ctl
            customised: root.themeState?.styleCustomised ?? false
            undoText: "Undo the style"
            undoArgs: ["style", "revert"]
            settingsModule: "kcm_style"
            settingsText: "Plasma's application style settings"
        }
    }

}
