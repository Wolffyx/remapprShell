pragma Singleton

// What the volume and microphone widgets show, as pure functions of the level
// and the mute they read: the theme icon, the Material Symbols glyph for the
// same state, and where a wheel notch takes the volume.
//
// StatusIcons forwards to every function here, so a widget that asks it keeps
// working; the icon names are Breeze's, for the reason given there.

import QtQuick

QtObject {
    id: root

    // 0..1 is 0..100%. Above 1 is amplification, which Plasma marks in two
    // steps so a boosted output never looks like an ordinary loud one.
    function volumeIcon(volume, muted) {
        if (muted || !(volume > 0))
            return "audio-volume-muted";
        if (volume <= 0.25)
            return "audio-volume-low";
        if (volume <= 0.75)
            return "audio-volume-medium";
        if (volume <= 1.0)
            return "audio-volume-high";
        if (volume <= 1.25)
            return "audio-volume-high-warning";
        return "audio-volume-high-danger";
    }

    function micIcon(volume, muted) {
        if (muted || !(volume > 0))
            return "microphone-sensitivity-muted";
        if (volume <= 0.25)
            return "microphone-sensitivity-low";
        if (volume <= 0.75)
            return "microphone-sensitivity-medium";
        return "microphone-sensitivity-high";
    }

    // The volume after `steps` wheel notches of `step` percent each. Steps can
    // be fractional -- a touchpad reports a fraction of a notch -- so the
    // result is rounded to a whole percent rather than snapped to the step
    // grid, which would make every small scroll jump a full step.
    //
    // `max` caps what scrolling can reach, not what the volume may be: an
    // output already boosted past it elsewhere scrolls down from where it is
    // rather than jumping to the cap on the first notch.
    function stepVolume(volume, steps, step, max) {
        const current = volume > 0 ? volume : 0;
        const next = Math.round((current + steps * step / 100) * 100) / 100;
        return Math.max(0, Math.min(Math.max(max, current), next));
    }

    // ---- glyphs ----------------------------------------------------------
    //
    // The same states as Material Symbols names, which is what the shell's
    // own look draws. Each follows the theme-icon rule above it, thresholds
    // and all, so the two can never say different things about one state.

    function volumeGlyph(volume, muted) {
        if (muted || !(volume > 0))
            return "volume_off";
        if (volume <= 0.25)
            return "volume_mute";
        if (volume <= 0.75)
            return "volume_down";
        return "volume_up";
    }

    function micGlyph(volume, muted) {
        return muted || !(volume > 0) ? "mic_off" : "mic";
    }
}
