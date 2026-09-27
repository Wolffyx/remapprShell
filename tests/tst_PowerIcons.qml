// Tests for what the battery widget shows.
//
// A battery at 100 drawn empty is the kind of bug nobody on a desktop machine
// would ever see to fix, so both scales a charge arrives in are pinned here,
// with the icons, glyphs and profile names read off them.

import QtQuick
import QtTest
import qs.domain.status.icons

TestCase {
    name: "PowerIcons"

    // Both scales are accepted; a full battery must never draw as empty.
    function test_battery_scale() {
        compare(PowerIcons.fraction(0.42), 0.42);
        compare(PowerIcons.fraction(42), 0.42);
        compare(PowerIcons.fraction(100), 1);
        compare(PowerIcons.fraction(0), 0);
        compare(PowerIcons.fraction(undefined), 0);
    }

    function test_battery_icon() {
        compare(PowerIcons.batteryIcon(1, false), "battery-100");
        compare(PowerIcons.batteryIcon(100, false), "battery-100");
        compare(PowerIcons.batteryIcon(0.04, false), "battery-000");
        compare(PowerIcons.batteryIcon(0.47, true), "battery-050-charging");
    }

    function test_profiles() {
        compare(PowerIcons.profileIcon("PowerSaver"), "battery-profile-powersave");
        compare(PowerIcons.profileIcon("Performance"), "battery-profile-performance");
        compare(PowerIcons.profileIcon("Balanced"), "battery-profile-balanced");
        compare(PowerIcons.profileLabel("PowerSaver"), "Power saver");
    }

    // ---- glyphs: the same states in Material Symbols -----------------------

    // Either scale, as the theme-icon rule accepts.
    function test_battery_glyph_levels() {
        compare(PowerIcons.batteryGlyph(1, false), "battery_full");
        compare(PowerIcons.batteryGlyph(100, false), "battery_full");
        compare(PowerIcons.batteryGlyph(0.84, false), "battery_5_bar");
        compare(PowerIcons.batteryGlyph(84, false), "battery_5_bar");
        compare(PowerIcons.batteryGlyph(0.12, false), "battery_1_bar");
        compare(PowerIcons.batteryGlyph(0.05, false), "battery_alert");
    }

    function test_battery_glyph_charging() {
        compare(PowerIcons.batteryGlyph(0.05, true), "battery_charging_20");
        compare(PowerIcons.batteryGlyph(0.55, true), "battery_charging_50");
        compare(PowerIcons.batteryGlyph(0.85, true), "battery_charging_80");
        compare(PowerIcons.batteryGlyph(0.97, true), "battery_charging_full");
    }

    function test_profile_glyphs() {
        compare(PowerIcons.profileGlyph("PowerSaver"), "eco");
        compare(PowerIcons.profileGlyph("Performance"), "speed");
        compare(PowerIcons.profileGlyph("Balanced"), "balance");
    }
}
