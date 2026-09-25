pragma Singleton

// The colours, type and shape the shell draws itself in.
//
// Material Design 3 roles in a light and a dark scheme, from one accent.
//
// With `theme.mode` at "auto" the shell is light by day and dark by night, on
// KWin's Night Light schedule -- the same sunset that warms the screen, so
// there is no second clock deciding when night is. Plasma itself has no
// automatic light/dark switching; its sunset belongs to the wallpaper. With
// Night Light off there is no schedule to follow, and auto falls back to
// turning dark exactly when the Plasma colour scheme is dark.
//
// PlasmaColors is still what reads the desktop; this turns what it read into
// the shell's own palette. The arithmetic is in Scheme, where it is tested.

import QtQuick
import qs.domain.config
import qs.domain.theme.palette
import qs.platform.kde

QtObject {
    id: root

    // ---- settings ----------------------------------------------------------

    readonly property string modeSetting: ConfigStore.value("theme.mode", "auto")
    readonly property string accentSetting: ConfigStore.value("theme.accent", "plasma")
    readonly property bool translucent: ConfigStore.value("theme.translucent", true) !== false

    // Off by default, and deliberately.
    //
    // A drop shadow is a band of dimmed wallpaper around a surface whose own
    // background the compositor has blurred. On a dark desktop the join
    // between the two reads as a second panel sitting behind the first, which
    // is how it was reported twice. It also costs the surface a transparent
    // border the width of the blur, which is room a popout has to keep clear
    // of everything it must not cover.
    readonly property bool shadows: ConfigStore.value("theme.shadows", false) === true
    readonly property int rounding: ConfigStore.value("theme.rounding", 28)

    // How long a surface takes to appear: a popout rising out of the panel,
    // the switcher, the overview. One number rather than one per surface, so
    // the shell moves at a single speed and a person who wants it immediate
    // says so once.
    readonly property int animationMs: Math.max(0, ConfigStore.value("theme.animationMs", 180))

    // ---- which scheme ------------------------------------------------------

    // "auto" follows Night Light's day and night when Night Light is on, and
    // the Plasma colour scheme's own darkness when it is not.
    //
    // Neither has answered in the first moments of a session: Night Light's
    // reply is still on its way, and kdeglobals has not been read. The
    // fallback palette in PlasmaColors is a dark one -- chosen so a shell that
    // cannot read the desktop is still legible -- so resolving "auto" against
    // it before it is real answers "dark" every single start.
    //
    // That was not merely a flash. With `theme.desktop.followMode` on, the
    // shell writes its own answer back to the desktop's colour scheme, and
    // then reads that scheme to answer again: a first frame of dark could be
    // written out and read back as the desktop's own darkness, and auto had
    // latched. Night Light answering in time was all that hid it.
    //
    // So "auto" does not answer until something has: the last mode stands
    // until then, rather than a placeholder getting a vote.
    readonly property bool modeKnown: root.modeSetting !== "auto"
                                      || PlasmaColors.loaded || NightLight.known

    readonly property string _resolvedMode: root.modeKnown
        ? Scheme.resolveMode(root.modeSetting,
                             PlasmaColors.background.toString(),
                             NightLight.known ? NightLight.daylight : undefined)
        : ""

    // Light while nothing is known, and not arbitrarily: of the two guesses
    // only this one is safe to write to a desktop. A wrong light is corrected
    // a moment later by the real answer; a wrong dark can be the answer.
    property string mode: "light"

    on_ResolvedModeChanged: if (root._resolvedMode.length > 0)
        root.mode = root._resolvedMode;

    readonly property bool dark: root.mode === "dark"
    readonly property string seed: Scheme.seed(root.accentSetting, PlasmaColors.accent.toString())
    readonly property var roles: Scheme.scheme(root.seed, root.dark)

    onModeChanged: console.info(`theme: ${root.mode} scheme (theme.mode: ${root.modeSetting})`)

    // ---- Material roles ----------------------------------------------------

    readonly property color primary: root.roles.primary
    readonly property color primaryFg: root.roles.onPrimary
    readonly property color primaryContainer: root.roles.primaryContainer
    readonly property color primaryContainerFg: root.roles.onPrimaryContainer
    readonly property color secondaryContainer: root.roles.secondaryContainer
    readonly property color secondaryContainerFg: root.roles.onSecondaryContainer
    readonly property color tertiary: root.roles.tertiary
    readonly property color tertiaryContainer: root.roles.tertiaryContainer
    readonly property color error: root.roles.error
    readonly property color errorFg: root.roles.onError
    readonly property color errorContainer: root.roles.errorContainer
    readonly property color errorContainerFg: root.roles.onErrorContainer
    readonly property color surface: root.roles.surface
    readonly property color surfaceDim: root.roles.surfaceDim
    readonly property color surfaceBright: root.roles.surfaceBright
    readonly property color surfaceContainerLowest: root.roles.surfaceContainerLowest
    readonly property color surfaceContainerLow: root.roles.surfaceContainerLow
    readonly property color surfaceContainer: root.roles.surfaceContainer
    readonly property color surfaceContainerHigh: root.roles.surfaceContainerHigh
    readonly property color surfaceContainerHighest: root.roles.surfaceContainerHighest
    readonly property color surfaceFg: root.roles.onSurface
    readonly property color surfaceVariantFg: root.roles.onSurfaceVariant
    readonly property color outline: root.roles.outline
    readonly property color outlineVariant: root.roles.outlineVariant
    readonly property color inverseSurface: root.roles.inverseSurface
    readonly property color inverseSurfaceFg: root.roles.inverseOnSurface
    readonly property color positive: root.roles.positive
    readonly property color warning: root.roles.warning

    // ---- what the shell draws with ------------------------------------------
    //
    // Short names for the handful of roles every surface uses, so a widget
    // says "the raised surface" rather than which Material container that is.

    // A window's or a popout's own ground, and the cards and fields on it.
    readonly property color s1: root.surfaceContainerLow
    readonly property color s2: root.surfaceContainerHigh
    // One step further from the ground than s2: a hovered card.
    readonly property color s3: root.dark ? root.surfaceContainerHighest : root.surfaceContainerLowest

    readonly property color fg: root.surfaceFg
    readonly property color mut: root.surfaceVariantFg
    readonly property color out: root.outlineVariant

    readonly property color acc: root.primary
    readonly property color accFg: root.primaryFg
    readonly property color accC: root.primaryContainer
    readonly property color accCFg: root.primaryContainerFg
    readonly property color danger: root.error

    // Frosted where the compositor blurs what is behind, which is the panel
    // and every popout. Solid when translucency is off.
    readonly property color glass: root.alpha(root.surfaceContainer, root.translucent ? (root.dark ? 0.86 : 0.88) : 1)
    readonly property color bar: root.alpha(root.surface, root.translucent ? (root.dark ? 0.80 : 0.82) : 1)

    readonly property color tipBg: root.dark ? root.surfaceContainerHighest : root.alpha(root.inverseSurface, 0.95)
    readonly property color tipFg: root.dark ? root.surfaceFg : root.inverseSurfaceFg
    readonly property color tipFgMut: root.alpha(root.tipFg, 0.72)

    // Material's state layers: the colour of the text on a surface, laid over
    // it thinly.
    readonly property color hover: root.alpha(root.surfaceFg, 0.08)
    readonly property color pressed: root.alpha(root.surfaceFg, 0.12)

    // The mockup casts every raised surface with rgba(20,15,10,.26) to .34,
    // in both themes. At 0.45 the dark shadow stopped reading as a shadow: a
    // popout's blur kept the card's silhouette, and on a screen it looked
    // like a second card sitting behind the card -- reported as exactly that.
    readonly property color shadow: root.alpha("#000000", root.dark ? 0.28 : 0.22)

    // ---- the names the shell used before it had a palette of its own --------
    //
    // PlasmaColors' names, so code written against it reads the same roles.

    readonly property color background: root.s1
    readonly property color backgroundAlternate: root.s2
    readonly property color foreground: root.fg
    readonly property color foregroundInactive: root.mut
    readonly property color accent: root.acc
    readonly property color negative: root.error
    readonly property color neutral: root.warning
    readonly property color selectionBackground: root.accC
    readonly property color selectionForeground: root.accCFg
    readonly property color panelBackground: root.bar
    readonly property color hoverBackground: root.hover
    readonly property color pressedBackground: root.pressed

    function alpha(c, a) {
        const q = Qt.color(c);
        return Qt.rgba(q.r, q.g, q.b, a);
    }

    // ---- type --------------------------------------------------------------

    readonly property var _families: Qt.fontFamilies()

    // Rubik where installed, the desktop's own font where it is not.
    readonly property string fontFamily: root._families.indexOf("Rubik") >= 0 ? "Rubik" : "sans-serif"

    // Material Symbols draws an icon from its name, as a ligature. Without the
    // font a name would be drawn as the word, so Glyph falls back to the icon
    // theme when this is false.
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property bool hasIconFont: root._families.indexOf(root.iconFont) >= 0

    readonly property string monoFamily: root._families.indexOf("JetBrains Mono") >= 0 ? "JetBrains Mono" : "monospace"

    // ---- shape -------------------------------------------------------------

    // Large surfaces -- the start menu, quick settings, the notification
    // centre -- take the setting; smaller things scale down from it, so a
    // square look is one slider away rather than a hundred edits.
    readonly property real radius: root.rounding

    // A radius from the design, rescaled to the rounding in force.
    //
    // The design is drawn at 28, and everything inside a popout was written
    // with its numbers -- a tile at 20, a row at 14, a chip at 6. Left alone
    // they do not follow `theme.rounding`, so at a small setting the card is
    // squarer than the things inside it and each one draws a rounder corner
    // inside the card's straighter one. That is what "a straight corner under
    // the corner with a radius" is.
    function radiusOf(designed) {
        return Math.round(designed * root.rounding / 28);
    }

    readonly property real radiusMedium: Math.round(root.rounding * 0.72)
    readonly property real radiusSmall: Math.round(root.rounding * 0.5)
    readonly property real radiusTiny: Math.round(root.rounding * 0.36)

    readonly property int durationFast: 120
    readonly property int durationMedium: 200
}
