pragma Singleton

// What the battery widget shows, as pure functions of what UPower and
// power-profiles-daemon report: the charge read on either scale, the theme
// icon and Material Symbols glyph for it, and the power profile's.
//
// StatusIcons forwards to every function here, so a widget that asks it keeps
// working; the icon names are Breeze's, for the reason given there.

import QtQuick

QtObject {
    id: root

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

    // ---- glyphs ----------------------------------------------------------
    //
    // The same states as Material Symbols names, which is what the shell's
    // own look draws. Each follows the theme-icon rule above it, scales and
    // all, so the two can never say different things about one state.

    // Material Symbols draws a battery in six bars, and a charging one at
    // seven marked levels. Under a tenth and not charging is an alert.
    function batteryGlyph(fraction, charging) {
        const f = root.fraction(fraction);
        if (charging) {
            if (f >= 0.95)
                return "battery_charging_full";
            const pct = f * 100;
            const level = pct < 30 ? 20 : pct < 50 ? 30 : pct < 60 ? 50 : pct < 80 ? 60 : pct < 90 ? 80 : 90;
            return `battery_charging_${level}`;
        }
        if (f >= 0.95)
            return "battery_full";
        if (f < 0.1)
            return "battery_alert";
        return `battery_${Math.max(1, Math.min(6, Math.round(f * 6)))}_bar`;
    }

    function profileGlyph(profile) {
        switch (profile) {
        case "PowerSaver":
            return "eco";
        case "Performance":
            return "speed";
        default:
            return "balance";
        }
    }
}
