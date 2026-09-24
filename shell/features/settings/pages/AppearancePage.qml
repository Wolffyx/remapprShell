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
//
// The cards that each write configuration keys of their own -- the colour
// scheme, the accent, the shape, and what the theme may change outside the
// shell -- are files of their own beside this one, named after the page. The
// cards that go through `theme` stay here, with the session they share.

import QtQuick
import qs.core
import qs.platform.system
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

    Component.onCompleted: root.ctl.refresh()

    AppearanceSchemeCard {
        width: root.width
    }

    AppearanceAccentCard {
        width: root.cellWidth
    }

    AppearanceShapeCard {
        width: root.cellWidth
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

        Hint {
            text: {
                const s = root.styles.find(x => x.id === root.themeState?.style);
                const what = s ? `${s.key}: ${s.label}. ` : "";
                return `${what}KDE applications already open change at once; others when next started.`;
            }
            lineHeight: 1
        }

        Repeater {
            model: root.styles.filter(s => !s.installed)

            Hint {
                required property var modelData

                text: modelData.install.length > 0
                    ? `${modelData.key} is not installed. In a terminal: ${modelData.install}`
                    : `${modelData.key} is not installed.`
                lineHeight: 1
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

        Hint {
            text: {
                if (!root.themeState)
                    return "";
                const state = root.themeState.active ? "Its look-and-feel package is active."
                            : root.themeState.package ? "Its look-and-feel package is installed but not active."
                            : "Not installed.";
                const gaps = root.missing.length > 0 ? ` Missing: ${root.missing.join(", ")}.` : " Every part is installed.";
                return state + gaps;
            }
            lineHeight: 1
        }

        TextButton {
            enabled: !root.ctl.busy
            iconName: "run-install"
            text: root.missing.length > 0
                  ? (root.themeState?.package ? "Install the missing parts and apply" : "Install the theme")
                  : "Apply the theme"
            onActivated: root.ctl.run(["apply"])
        }

        Hint {
            text: "A restore point is taken first, and every key is recorded, so \"Undo everything\" puts the desktop back exactly as it was."
            lineHeight: 1
        }
    }

    AppearanceDesktopCard {
        width: root.width
        gtkThemes: root.gtkThemes
        materialYouInstalled: root.materialYouInstalled
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
