// Tests for what the volume and microphone widgets show.
//
// A muted output that shows a speaker, or a boosted one that looks ordinary,
// is a thing a person reads at a glance and trusts -- so the thresholds are
// pinned here, glyphs and theme icons alike, and so is the wheel's step.

import QtQuick
import QtTest
import qs.domain.status.icons

TestCase {
    name: "AudioIcons"

    function test_muted_wins_over_any_volume() {
        compare(AudioIcons.volumeIcon(0.8, true), "audio-volume-muted");
        compare(AudioIcons.volumeIcon(0, false), "audio-volume-muted");
    }

    function test_volume_levels() {
        compare(AudioIcons.volumeIcon(0.1, false), "audio-volume-low");
        compare(AudioIcons.volumeIcon(0.5, false), "audio-volume-medium");
        compare(AudioIcons.volumeIcon(1.0, false), "audio-volume-high");
    }

    // Amplified output must never look like an ordinary loud one.
    function test_boosted_volume_is_marked() {
        compare(AudioIcons.volumeIcon(1.1, false), "audio-volume-high-warning");
        compare(AudioIcons.volumeIcon(1.5, false), "audio-volume-high-danger");
    }

    function test_mic_levels() {
        compare(AudioIcons.micIcon(0.5, true), "microphone-sensitivity-muted");
        compare(AudioIcons.micIcon(0.9, false), "microphone-sensitivity-high");
    }

    function test_wheel_steps_and_clamps() {
        compare(AudioIcons.stepVolume(0.5, 1, 5, 1.0), 0.55);
        compare(AudioIcons.stepVolume(0.5, -2, 5, 1.0), 0.4);
        compare(AudioIcons.stepVolume(0.98, 1, 5, 1.0), 1.0);
        compare(AudioIcons.stepVolume(0.02, -1, 5, 1.0), 0);
    }

    // A touchpad reports fractions of a notch; each must move the volume a
    // little rather than a whole step or nothing.
    function test_fractional_steps_round_to_a_percent() {
        compare(AudioIcons.stepVolume(0.5, 0.4, 5, 1.0), 0.52);
    }

    // Boosted elsewhere past the cap: scrolling down starts from where it is,
    // and scrolling up does not push it further.
    function test_volume_above_the_cap_is_not_snapped_down() {
        compare(AudioIcons.stepVolume(1.3, -1, 5, 1.0), 1.25);
        compare(AudioIcons.stepVolume(1.3, 1, 5, 1.0), 1.3);
    }

    // ---- glyphs: the same states in Material Symbols -----------------------

    function test_volume_glyph_follows_the_icon_thresholds() {
        compare(AudioIcons.volumeGlyph(0.8, true), "volume_off");
        compare(AudioIcons.volumeGlyph(0, false), "volume_off");
        compare(AudioIcons.volumeGlyph(0.2, false), "volume_mute");
        compare(AudioIcons.volumeGlyph(0.5, false), "volume_down");
        compare(AudioIcons.volumeGlyph(1.0, false), "volume_up");
        compare(AudioIcons.volumeGlyph(1.4, false), "volume_up");
    }

    function test_mic_glyph() {
        compare(AudioIcons.micGlyph(0.5, false), "mic");
        compare(AudioIcons.micGlyph(0.5, true), "mic_off");
        compare(AudioIcons.micGlyph(0, false), "mic_off");
    }
}
