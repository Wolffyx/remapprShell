pragma Singleton

// What the status widgets show, as pure functions of the state they read.
//
// Kept apart from the singletons that read PipeWire, NetworkManager, BlueZ and
// UPower, in a module of its own, so qmltestrunner can load it: a module with
// one Quickshell import in it cannot be imported by the tests at all, and
// every pure function beside it becomes untestable by association.
//
// The icon names are Breeze's, and they are the ones Plasma's own applets ask
// for -- so a panel drawn by us and one drawn by Plasma show the same glyph
// for the same state, and an icon theme that styles one styles both.

import QtQuick

QtObject {
    id: root

    // ---- audio -----------------------------------------------------------

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

    // ---- network ---------------------------------------------------------

    // Signal strength 0..1.
    function wifiIcon(strength) {
        if (!(strength > 0.05))
            return "network-wireless-signal-none";
        if (strength < 0.3)
            return "network-wireless-signal-weak";
        if (strength < 0.55)
            return "network-wireless-signal-ok";
        if (strength < 0.8)
            return "network-wireless-signal-good";
        return "network-wireless-signal-excellent";
    }

    // Whether NetworkManager's connectivity check says the connection does not
    // reach the internet. "Unknown" is what it says when the check is off, and
    // is not a problem worth a warning glyph.
    function isLimited(connectivity) {
        return connectivity === "Limited" || connectivity === "Portal" || connectivity === "None";
    }

    // s: { wired, wifi, strength, connectivity }. A wired link wins when both
    // are up, because that is the one NetworkManager routes through by default
    // and the one Plasma's applet shows.
    function networkIcon(s) {
        const limited = root.isLimited(s?.connectivity ?? "Unknown");
        if (s?.wired)
            return limited ? "network-wired-activated-limited" : "network-wired-activated";
        if (s?.wifi)
            return limited ? "network-limited" : root.wifiIcon(s.strength ?? 0);
        return "network-offline";
    }

    // Mbit/s, as NetworkManager reports it. Zero means unknown, not slow.
    function linkSpeed(mbps) {
        if (!(mbps > 0))
            return "";
        return mbps >= 1000 ? `${mbps / 1000} Gbit/s` : `${mbps} Mbit/s`;
    }

    // ---- bluetooth -------------------------------------------------------

    function bluetoothIcon(enabled, connected) {
        if (!enabled)
            return "network-bluetooth-inactive-symbolic";
        return connected > 0 ? "network-bluetooth-activated" : "network-bluetooth";
    }

    // ---- power -----------------------------------------------------------

    // Quickshell documents a battery's charge as 0..1; UPower itself says
    // 0..100 on the bus. Both are accepted, because which one arrives is a
    // detail of a library version and a battery at "100" drawn as empty is
    // the kind of bug nobody on a desktop machine would ever see to fix.
    function fraction(p) {
        if (!(p > 0))
            return 0;
        return p > 1 ? Math.min(1, p / 100) : p;
    }

    function batteryIcon(fraction, charging) {
        const level = Math.max(0, Math.min(100, Math.round(root.fraction(fraction) * 10) * 10));
        const padded = String(level).padStart(3, "0");
        return `battery-${padded}${charging ? "-charging" : ""}`;
    }

    // "PowerSaver" | "Balanced" | "Performance", as power-profiles-daemon names them.
    function profileIcon(profile) {
        switch (profile) {
        case "PowerSaver":
            return "battery-profile-powersave";
        case "Performance":
            return "battery-profile-performance";
        default:
            return "battery-profile-balanced";
        }
    }

    function profileLabel(profile) {
        switch (profile) {
        case "PowerSaver":
            return "Power saver";
        case "Performance":
            return "Performance";
        default:
            return "Balanced";
        }
    }

    // ---- text ------------------------------------------------------------

    function percent(v) {
        return `${Math.round((v > 0 ? v : 0) * 100)}%`;
    }

    // Seconds to "1 h 05 min" or "45 min". Nothing for an unknown time, which
    // UPower reports as zero -- a battery is never "0 min" from anything.
    function duration(seconds) {
        if (!(seconds > 0))
            return "";
        let h = Math.floor(seconds / 3600);
        let m = Math.round((seconds - h * 3600) / 60);
        if (m === 60) {
            h += 1;
            m = 0;
        }
        if (h === 0)
            return `${Math.max(1, m)} min`;
        return `${h} h ${String(m).padStart(2, "0")} min`;
    }
}
