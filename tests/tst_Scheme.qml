// Tests for the Material colour roles the shell draws itself in: the colour
// arithmetic, the tones, the two schemes, and which of them is chosen.
//
// Reference values are the published ones (CIELAB of sRGB primaries, the CSS
// Color 4 OKLCH of sRGB red and blue), not numbers taken from this code.

import QtQuick
import QtTest
import qs.domain.theme.palette

TestCase {
    name: "Scheme"

    function near(actual, expected, tolerance, what) {
        verify(Math.abs(actual - expected) <= tolerance,
               `${what}: ${actual} is not within ${tolerance} of ${expected}`);
    }

    function nearRgb(actual, expected, tolerance) {
        const a = Scheme.parse(actual), e = Scheme.parse(expected);
        near(a.r, e.r, tolerance, `${actual} red`);
        near(a.g, e.g, tolerance, `${actual} green`);
        near(a.b, e.b, tolerance, `${actual} blue`);
    }

    // ---- reading colours ---------------------------------------------------

    function test_every_way_a_colour_arrives() {
        compare(Scheme.normalise("#abc", ""), "#aabbcc");
        compare(Scheme.normalise("#1F2E3D", ""), "#1f2e3d");
        compare(Scheme.normalise("#801f2e3d", ""), "#1f2e3d");
        compare(Scheme.normalise("61,174,233", ""), "#3daee9");
        compare(Scheme.normalise(" 255, 0 ,0 ", ""), "#ff0000");
    }

    function test_nonsense_is_the_fallback() {
        compare(Scheme.normalise("", "#010203"), "#010203");
        compare(Scheme.normalise("blue-ish", "#010203"), "#010203");
        compare(Scheme.normalise(undefined, "#010203"), "#010203");
        compare(Scheme.parse("rgb(1,2,3)"), null);
    }

    function test_alpha_is_written_first_as_qml_reads_it() {
        compare(Scheme.withAlpha("#102030", 1), "#ff102030");
        compare(Scheme.withAlpha("#102030", 0), "#00102030");
        compare(Scheme.withAlpha("#102030", 0.8), "#cc102030");
    }

    // ---- CIELAB ------------------------------------------------------------

    function test_lightness_of_the_greys() {
        near(Scheme.lab("#ffffff").l, 100, 0.01, "white");
        near(Scheme.lab("#000000").l, 0, 0.01, "black");
        near(Scheme.lab("#808080").l, 53.585, 0.01, "mid grey");
        near(Scheme.lch("#808080").c, 0, 0.01, "grey has no chroma");
    }

    function test_lab_of_srgb_red() {
        const c = Scheme.lab("#ff0000");
        near(c.l, 53.24, 0.05, "L");
        near(c.a, 80.09, 0.05, "a");
        near(c.b, 67.20, 0.05, "b");
        near(Scheme.lch("#ff0000").h, 40.0, 0.1, "hue");
    }

    // ---- OKLCH, for the design's accents -----------------------------------

    function test_oklch_of_known_colours() {
        nearRgb(Scheme.normalise("oklch(0.62796 0.25768 29.2339)", ""), "#ff0000", 1);
        nearRgb(Scheme.normalise("oklch(0.45201 0.31321 264.052)", ""), "#0000ff", 1);
        nearRgb(Scheme.normalise("oklch(1 0 0)", ""), "#ffffff", 1);
        nearRgb(Scheme.normalise("oklch(62.796% 0.25768 29.2339)", ""), "#ff0000", 1);
    }

    function test_the_designs_blue_is_a_blue() {
        const c = Scheme.lch(Scheme.seed("blue", ""));
        verify(c.h > 260 && c.h < 310, `hue ${c.h}`);
        verify(c.c > 40, `chroma ${c.c}`);
    }

    // ---- tones -------------------------------------------------------------

    function test_a_tone_is_its_lightness() {
        for (const hue of [0, 40, 145, 262, 320]) {
            for (const t of [4, 10, 20, 30, 40, 50, 80, 90, 96, 98]) {
                near(Scheme.lab(Scheme.tone(hue, 40, t)).l, t, 0.6, `hue ${hue} tone ${t}`);
            }
        }
    }

    function test_the_ends_are_black_and_white() {
        compare(Scheme.tone(262, 60, 0), "#000000");
        compare(Scheme.tone(262, 60, 100), "#ffffff");
    }

    // A chroma that does not exist at that tone is given up, not the hue.
    function test_out_of_gamut_keeps_the_hue() {
        const c = Scheme.lch(Scheme.tone(262, 200, 50));
        verify(c.c < 200 && c.c > 20, `chroma ${c.c}`);
        near(c.h, 262, 3, "hue");
    }

    // ---- the schemes -------------------------------------------------------

    function test_light_scheme_tones() {
        const s = Scheme.scheme(Scheme.seed("blue", ""), false);
        verify(!s.dark);
        near(Scheme.lab(s.primary).l, 40, 0.6, "primary");
        compare(s.onPrimary, "#ffffff");
        near(Scheme.lab(s.surface).l, 98, 0.6, "surface");
        near(Scheme.lab(s.surfaceContainerHigh).l, 92, 0.6, "surfaceContainerHigh");
        near(Scheme.lab(s.onSurface).l, 10, 0.6, "onSurface");
    }

    function test_dark_scheme_tones() {
        const s = Scheme.scheme(Scheme.seed("blue", ""), true);
        verify(s.dark);
        near(Scheme.lab(s.primary).l, 80, 0.6, "primary");
        near(Scheme.lab(s.surface).l, 6, 0.6, "surface");
        near(Scheme.lab(s.surfaceContainerHighest).l, 22, 0.6, "surfaceContainerHighest");
        near(Scheme.lab(s.onSurface).l, 90, 0.6, "onSurface");
    }

    // What Material's tones are for: text stays readable on every surface,
    // whichever accent was picked.
    function test_text_is_readable_in_both_schemes() {
        for (const accent of ["blue", "teal", "magenta", "orange", "#3daee9", "#808080"]) {
            for (const dark of [false, true]) {
                const s = Scheme.scheme(Scheme.seed(accent, ""), dark);
                const what = `${accent} ${dark ? "dark" : "light"}`;
                verify(Scheme.contrast(s.onSurface, s.surface) >= 7, `${what}: onSurface`);
                verify(Scheme.contrast(s.onSurface, s.surfaceContainerHighest) >= 7, `${what}: onSurface on the highest container`);
                verify(Scheme.contrast(s.onSurfaceVariant, s.surfaceContainerHigh) >= 4.5, `${what}: onSurfaceVariant`);
                verify(Scheme.contrast(s.onPrimary, s.primary) >= 4.5, `${what}: onPrimary`);
                verify(Scheme.contrast(s.onPrimaryContainer, s.primaryContainer) >= 4.5, `${what}: onPrimaryContainer`);
            }
        }
    }

    function test_the_containers_step_in_order() {
        const light = Scheme.scheme(Scheme.seed("teal", ""), false);
        const L = k => Scheme.lab(light[k]).l;
        verify(L("surfaceContainerLowest") > L("surfaceContainerLow"));
        verify(L("surfaceContainerLow") > L("surfaceContainer"));
        verify(L("surfaceContainer") > L("surfaceContainerHigh"));
        verify(L("surfaceContainerHigh") > L("surfaceContainerHighest"));

        const dark = Scheme.scheme(Scheme.seed("teal", ""), true);
        const D = k => Scheme.lab(dark[k]).l;
        verify(D("surfaceContainerLowest") < D("surfaceContainerLow"));
        verify(D("surfaceContainerHigh") < D("surfaceContainerHighest"));
    }

    function test_a_grey_seed_gives_a_grey_scheme() {
        const s = Scheme.scheme("#808080", false);
        verify(Scheme.lch(s.primary).c < 8, `primary chroma ${Scheme.lch(s.primary).c}`);
        verify(Scheme.lch(s.surface).c < 2, `surface chroma ${Scheme.lch(s.surface).c}`);
    }

    function test_a_pale_seed_still_gives_a_coloured_accent() {
        // A pastel accent, as Material You schemes pick from a wallpaper.
        const s = Scheme.scheme("#c2c0eb", false);
        verify(Scheme.lch(s.primary).c >= 30, `primary chroma ${Scheme.lch(s.primary).c}`);
    }

    // ---- which scheme ------------------------------------------------------

    function test_explicit_mode_wins() {
        compare(Scheme.resolveMode("light", "#101010"), "light");
        compare(Scheme.resolveMode("dark", "#fafafa"), "dark");
    }

    function test_auto_follows_the_plasma_background() {
        compare(Scheme.resolveMode("auto", "#1b1e20"), "dark");   // Breeze Dark
        compare(Scheme.resolveMode("auto", "#eff0f1"), "light");  // Breeze
        compare(Scheme.resolveMode("auto", "35,38,41"), "dark");
    }

    function test_an_unknown_mode_is_auto() {
        compare(Scheme.resolveMode("sepia", "#1b1e20"), "dark");
        compare(Scheme.resolveMode(undefined, "#eff0f1"), "light");
    }

    function test_no_background_yet_is_light() {
        compare(Scheme.resolveMode("auto", ""), "light");
    }

    function test_the_seed() {
        compare(Scheme.seed("plasma", "61,174,233"), "#3daee9");
        compare(Scheme.seed("plasma", ""), Scheme.seed("blue", ""));
        compare(Scheme.seed("#123456", ""), "#123456");
        compare(Scheme.seed("chartreuse", ""), Scheme.seed("blue", ""));
        verify(Scheme.seed("teal", "") !== Scheme.seed("orange", ""));
    }
}
