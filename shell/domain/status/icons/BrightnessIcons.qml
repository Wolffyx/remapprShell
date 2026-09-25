pragma Singleton

// What the brightness widget shows, as pure functions of what powerdevil and
// KWin's Night Light report: the displays read off the bus, where a slider or
// a wheel notch takes one, Night Light reduced to a state, and the theme icon
// and Material Symbols glyph for each -- including the one glyph the panel
// has room for.
//
// StatusIcons forwards to every function here, so a widget that asks it keeps
// working; the icon names are Breeze's, for the reason given there.

import QtQuick
import qs.core

QtObject {
    id: root

    // powerdevil's displays, from lines of "<name> <GetAll reply>", one per
    // display. A line that does not parse, or a display with no range, is
    // dropped rather than drawn as a screen at 0%.
    function brightnessDisplays(lines) {
        const out = [];
        for (const line of lines ?? []) {
            const s = String(line ?? "").trim();
            const space = s.indexOf(" ");
            if (space <= 0)
                continue;
            let props;
            try {
                props = BusLine.props(JSON.parse(s.slice(space + 1)).data);
            } catch (e) {
                continue;
            }
            if (!(props.MaxBrightness > 0))
                continue;
            out.push({
                name: s.slice(0, space),
                label: props.Label ?? "",
                brightness: Math.max(0, props.Brightness ?? 0),
                max: props.MaxBrightness,
                internal: !!props.IsInternal
            });
        }
        return out;
    }

    // The lowest a slider or a scroll takes a display: 1%. The bottom of the
    // range turns some panels' backlight off altogether, and nothing on the
    // panel should be able to black out the screen it is being read on.
    function brightnessFloor(max) {
        return max > 0 ? Math.ceil(max / 100) : 0;
    }

    // The raw value `steps` wheel notches of `step` percent from `value`, on
    // a display whose top is `max`. A display already below the floor --
    // dimmed that far by something else -- is not brightened by scrolling
    // down, the rule AudioIcons.stepVolume follows at the other end.
    function stepBrightness(value, max, steps, step) {
        if (!(max > 0))
            return 0;
        const current = Math.max(0, Math.min(max, value > 0 ? value : 0));
        const next = Math.round(current + steps * step * max / 100);
        return Math.max(Math.min(root.brightnessFloor(max), current), Math.min(max, next));
    }

    // The raw value a slider at `percent` asks for, on a display whose top
    // is `max`: never below the floor, so the bottom of a slider cannot black
    // out the screen it is drawn on.
    function brightnessFromPercent(percent, max) {
        return Math.max(root.brightnessFloor(max), Math.round(percent * max / 100));
    }

    function brightnessIcon(fraction) {
        return fraction < 0.5 ? "brightness-low" : "brightness-high";
    }

    // KWin's Night Light, reduced to what a panel says about it. `nl` is its
    // DBus properties: { available, enabled, inhibited, currentTemperature }.
    //   "unavailable" -- the compositor cannot tint this screen
    //   "off"         -- turned off in System Settings
    //   "suspended"   -- on, but held off for now
    //   "warm"        -- tinting the screen at this moment
    //   "day"         -- on, and not tinting yet
    // "Warm" is read off the temperature rather than off `daylight`: 6500 K is
    // KWin's neutral, and a day temperature set below it is a tinted screen
    // in daylight, which is what the widget should then say.
    function nightLightState(nl) {
        if (!nl?.available)
            return "unavailable";
        if (!nl.enabled)
            return "off";
        if (nl.inhibited)
            return "suspended";
        return (nl.currentTemperature ?? 6500) < 6500 ? "warm" : "day";
    }

    function nightLightLabel(nl) {
        switch (root.nightLightState(nl)) {
        case "unavailable":
            return "Night Light is not available here";
        case "off":
            return "Night Light is off";
        case "suspended":
            return "Night Light is suspended";
        case "warm":
            return `Night Light · ${nl.currentTemperature} K`;
        default:
            return "Night Light is on";
        }
    }

    function nightLightIcon(state) {
        switch (state) {
        case "warm":
            return "redshift-status-on";
        case "day":
            return "redshift-status-day";
        default:
            return "redshift-status-off";
        }
    }

    // The one glyph on the panel. Night Light wins while it is doing
    // something the user would want to know about -- tinting, or held off by
    // them -- and otherwise the brightness shows; with no display to dim,
    // Night Light is all there is.
    function brightnessPanelIcon(fraction, hasDisplays, nightState) {
        if (nightState === "warm" || nightState === "suspended" || !hasDisplays)
            return root.nightLightIcon(nightState);
        return root.brightnessIcon(fraction);
    }

    // ---- glyphs ----------------------------------------------------------
    //
    // The same states as Material Symbols names, which is what the shell's
    // own look draws. Each follows the theme-icon rule above it, so the two
    // can never say different things about one state.

    function brightnessGlyph(fraction) {
        if (fraction < 0.34)
            return "brightness_low";
        return fraction < 0.67 ? "brightness_medium" : "brightness_high";
    }

    function nightLightGlyph(state) {
        switch (state) {
        case "warm":
            return "nightlight";
        case "suspended":
            return "bedtime_off";
        case "day":
            return "light_mode";
        default:
            return "dark_mode";
        }
    }

    function brightnessPanelGlyph(fraction, hasDisplays, nightState) {
        if (nightState === "warm" || nightState === "suspended" || !hasDisplays)
            return root.nightLightGlyph(nightState);
        return root.brightnessGlyph(fraction);
    }
}
