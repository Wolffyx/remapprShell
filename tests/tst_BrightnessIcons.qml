// Tests for what the brightness widget shows.
//
// Two rules here protect the screen the panel is read on: nothing a slider or
// a wheel does can take a display to black, and Night Light is read off what
// KWin says rather than guessed. Both are pinned, with the replies they are
// read from, and so are the icons and glyphs drawn for them.

import QtQuick
import QtTest
import qs.core
import qs.domain.status.icons

TestCase {
    name: "BrightnessIcons"

    // The shape powerdevil replies with for an external monitor over DDC,
    // with the model name it carries replaced by a stand-in: what is under
    // test is the flattening, and the label is a string like any other.
    readonly property string external: '{"type":"a{sv}","data":[{"Brightness":{"type":"i","data":7500},'
        + '"IsInternal":{"type":"b","data":false},"Label":{"type":"s","data":"EXA Displays 27Q"},'
        + '"MaxBrightness":{"type":"i","data":10000}}]}'

    function test_displays_are_read_one_per_line() {
        const d = BrightnessIcons.brightnessDisplays([`display0 ${external}`, ""]);
        compare(d.length, 1);
        compare(d[0].name, "display0");
        compare(d[0].brightness, 7500);
        compare(d[0].max, 10000);
        compare(d[0].internal, false);
    }

    // A reply that is not JSON, or a display with no range, is not a screen
    // at 0% -- it is not listed at all.
    function test_unreadable_displays_are_dropped() {
        const noRange = '{"type":"a{sv}","data":[{"Brightness":{"type":"i","data":5},'
            + '"MaxBrightness":{"type":"i","data":0}}]}';
        compare(BrightnessIcons.brightnessDisplays(["display1 Failed to get", `display2 ${noRange}`, "lonely"]).length, 0);
    }

    function test_brightness_steps_in_percent_of_the_range() {
        compare(BrightnessIcons.stepBrightness(5000, 10000, 1, 5), 5500);
        compare(BrightnessIcons.stepBrightness(5000, 10000, -2, 5), 4000);
        compare(BrightnessIcons.stepBrightness(9800, 10000, 1, 5), 10000);
    }

    // A laptop panel with a range of 15 still moves, and in whole steps.
    function test_a_short_range_still_moves() {
        compare(BrightnessIcons.stepBrightness(7, 15, 1, 5), 8);
        compare(BrightnessIcons.stepBrightness(7, 15, -1, 5), 6);
    }

    // Scrolling down stops at 1%: the bottom of the range is a black screen
    // on some panels.
    function test_scrolling_never_reaches_black() {
        compare(BrightnessIcons.stepBrightness(300, 10000, -5, 5), 100);
        compare(BrightnessIcons.stepBrightness(1, 15, -1, 5), 1);
        compare(BrightnessIcons.brightnessFloor(10000), 100);
        compare(BrightnessIcons.brightnessFloor(15), 1);
    }

    // A slider's percent as a raw value: 1% at the bottom, never below.
    function test_a_percent_is_a_raw_value_above_the_floor() {
        compare(BrightnessIcons.brightnessFromPercent(50, 10000), 5000);
        compare(BrightnessIcons.brightnessFromPercent(100, 15), 15);
        compare(BrightnessIcons.brightnessFromPercent(33, 15), 5);
        compare(BrightnessIcons.brightnessFromPercent(1, 10000), 100);
        compare(BrightnessIcons.brightnessFromPercent(0, 10000), 100);
        compare(BrightnessIcons.brightnessFromPercent(0, 15), 1);
    }

    // Dimmed below the floor elsewhere: scrolling down leaves it there
    // rather than brightening it, and scrolling up starts from where it is.
    function test_below_the_floor_is_not_snapped_up() {
        compare(BrightnessIcons.stepBrightness(0, 10000, -1, 5), 0);
        compare(BrightnessIcons.stepBrightness(0, 10000, 1, 5), 500);
    }

    function nl(props) {
        return Object.assign({ available: true, enabled: true, inhibited: false, currentTemperature: 6500 }, props);
    }

    // KWin's reply to Properties.GetAll on /org/kde/KWin/NightLight, in the
    // shape busctl gives it, trimmed to the properties read here. NightLight
    // flattens it with BusLine.props, and the brightness widget reads the
    // result through BusLine too: the one read serves both.
    readonly property string nightGetAll: '{"type":"a{sv}","data":[{'
        + '"available":{"type":"b","data":true},"enabled":{"type":"b","data":true},'
        + '"inhibited":{"type":"b","data":false},"daylight":{"type":"b","data":false},'
        + '"currentTemperature":{"type":"u","data":4500},"mode":{"type":"u","data":0},'
        + '"scheduledTransitionDateTime":{"type":"t","data":1790000000}}]}'

    function test_night_light_from_its_bus_reply() {
        const nl = BusLine.props(JSON.parse(nightGetAll).data);
        compare(BrightnessIcons.nightLightState(nl), "warm");
        compare(nl.daylight, false);
        compare(nl.scheduledTransitionDateTime, 1790000000);
        // No reply at all is no Night Light, not an error.
        compare(BrightnessIcons.nightLightState(BusLine.props(undefined)), "unavailable");
    }

    function test_night_light_states() {
        compare(BrightnessIcons.nightLightState({}), "unavailable");
        compare(BrightnessIcons.nightLightState(nl({ available: false })), "unavailable");
        compare(BrightnessIcons.nightLightState(nl({ enabled: false })), "off");
        compare(BrightnessIcons.nightLightState(nl({ inhibited: true, currentTemperature: 4500 })), "suspended");
        compare(BrightnessIcons.nightLightState(nl({ currentTemperature: 4500 })), "warm");
        compare(BrightnessIcons.nightLightState(nl({})), "day");
    }

    // A day temperature set below neutral is a tinted screen in daylight.
    function test_a_warm_day_is_warm() {
        compare(BrightnessIcons.nightLightState(nl({ currentTemperature: 6000 })), "warm");
    }

    function test_night_light_label_gives_the_temperature() {
        compare(BrightnessIcons.nightLightLabel(nl({ currentTemperature: 4500 })), "Night Light · 4500 K");
        compare(BrightnessIcons.nightLightLabel(nl({ inhibited: true })), "Night Light is suspended");
    }

    // Night Light takes the panel icon while it tints, or while the user
    // holds it off; otherwise it is the brightness.
    function test_panel_icon() {
        compare(BrightnessIcons.brightnessPanelIcon(0.8, true, "day"), "brightness-high");
        compare(BrightnessIcons.brightnessPanelIcon(0.2, true, "off"), "brightness-low");
        compare(BrightnessIcons.brightnessPanelIcon(0.8, true, "warm"), "redshift-status-on");
        compare(BrightnessIcons.brightnessPanelIcon(0.8, true, "suspended"), "redshift-status-off");
        compare(BrightnessIcons.brightnessPanelIcon(0, false, "day"), "redshift-status-day");
    }

    // ---- glyphs: the same states in Material Symbols -----------------------

    function test_brightness_glyphs() {
        compare(BrightnessIcons.brightnessGlyph(0.2), "brightness_low");
        compare(BrightnessIcons.brightnessGlyph(0.5), "brightness_medium");
        compare(BrightnessIcons.brightnessGlyph(0.9), "brightness_high");
    }

    // Night Light wins while it is doing something, as the icon rule does.
    function test_brightness_panel_glyph() {
        compare(BrightnessIcons.brightnessPanelGlyph(0.9, true, "warm"), "nightlight");
        compare(BrightnessIcons.brightnessPanelGlyph(0.9, true, "suspended"), "bedtime_off");
        compare(BrightnessIcons.brightnessPanelGlyph(0.9, true, "day"), "brightness_high");
        compare(BrightnessIcons.brightnessPanelGlyph(0.9, false, "day"), "light_mode");
    }
}
