// Prints the two palettes the Plasma colour schemes are generated from, as
// JSON, taken from the shell's own Material scheme.
//
// Run by scripts/gen-palette.sh, offscreen, and by nothing else. It exists so
// that the colours KDE's applications are drawn in and the colours this shell
// draws itself in come from one place: Scheme.qml. Written by hand in two
// files, they drift, and the drift shows up as a dialogue that does not match
// the panel it opened from.

import QtQuick
import Quickshell
import qs.domain.theme.palette

ShellRoot {
    id: root

    // The design's blue rather than "plasma": a generated file must be the
    // same on every machine, and Plasma's own accent is whatever the person
    // running it has chosen -- which the shell follows live anyway.
    readonly property string seed: Quickshell.env("PALETTE_SEED") || "blue"

    function rgb(hex) {
        const c = Qt.color(hex);
        return `${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)}`;
    }

    // Which Material role each of the colour scheme's colours is. The names on
    // the left are Plasma's idea of a palette; the ones on the right are
    // Material's, and the mapping is the whole translation between them.
    function palette(dark) {
        const r = Scheme.scheme(Scheme.seed(root.seed, ""), dark);
        return {
            windowBackground: root.rgb(r.surfaceContainer),
            windowAlternate: root.rgb(r.surfaceContainerHigh),
            viewBackground: root.rgb(r.surfaceContainerLowest),
            viewAlternate: root.rgb(r.surfaceContainerLow),
            buttonBackground: root.rgb(r.surfaceContainerHigh),
            buttonAlternate: root.rgb(r.surfaceContainerHighest),
            foreground: root.rgb(r.onSurface),
            foregroundInactive: root.rgb(r.onSurfaceVariant),
            accent: root.rgb(r.primary),
            accentText: root.rgb(r.onPrimary),
            positive: root.rgb(r.positive),
            neutral: root.rgb(r.warning),
            negative: root.rgb(r.error),
            link: root.rgb(r.primary),
            visited: root.rgb(r.tertiary),
            // The same surface tone in both, and deliberately not the
            // inverse one. Material's tooltip is inverseSurface *paired with*
            // inverseOnSurface; KDE's `[Colors:Tooltip]` takes its foreground
            // from the same foreground every other group uses, so inverting
            // only the background gave the light scheme a near-black tooltip
            // with near-black text on it.
            tooltipBackground: root.rgb(r.surfaceContainerHighest),
            titlebarActive: root.rgb(r.surfaceContainerHigh),
            titlebarInactive: root.rgb(r.surfaceContainer),
            disabled: root.rgb(r.outlineVariant)
        };
    }

    Component.onCompleted: {
        console.info("PALETTE " + JSON.stringify({ dark: root.palette(true), light: root.palette(false) }));
        Qt.quit();
    }
}
