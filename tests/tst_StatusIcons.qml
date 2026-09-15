// Tests for what the status widgets show.
//
// Each rule here is one a person reads at a glance and trusts: a muted output
// that shows a speaker, a boosted one that looks ordinary, a battery at 100
// drawn empty. None of them can be checked on a desktop with no battery, so
// they are pinned here rather than left to be found on someone's laptop.

import QtQuick
import QtTest
import qs.domain.status.icons

TestCase {
    name: "StatusIcons"

    // ---- the OSD ----------------------------------------------------------

    function test_osd_glyphs() {
        compare(StatusIcons.osdGlyph("audio-volume-high", 0.9), "volume_up");
        compare(StatusIcons.osdGlyph("audio-volume-low", 0.1), "volume_mute");
        compare(StatusIcons.osdGlyph("audio-volume-muted", 0.6), "volume_off");
        compare(StatusIcons.osdGlyph("microphone-sensitivity-muted", 0), "mic_off");
        compare(StatusIcons.osdGlyph("video-display-brightness", 0.2), "brightness_low");
        compare(StatusIcons.osdGlyph("input-keyboard-brightness", 0.5), "keyboard");
        compare(StatusIcons.osdGlyph("input-touchpad-off", 0), "touchpad_mouse_off");
        compare(StatusIcons.osdGlyph("something-else", 0), "");
    }

    // ---- Bluetooth devices, and nmcli -------------------------------------

    function test_device_glyphs() {
        compare(StatusIcons.deviceGlyph("audio-headset"), "headphones");
        compare(StatusIcons.deviceGlyph("audio-headphones"), "headphones");
        compare(StatusIcons.deviceGlyph("audio-card"), "speaker");
        compare(StatusIcons.deviceGlyph("input-keyboard"), "keyboard");
        compare(StatusIcons.deviceGlyph("input-mouse"), "mouse");
        compare(StatusIcons.deviceGlyph("phone"), "smartphone");
        compare(StatusIcons.deviceGlyph("input-gaming"), "sports_esports");
        compare(StatusIcons.deviceGlyph(""), "bluetooth");
        compare(StatusIcons.deviceGlyph(undefined), "bluetooth");
    }

    // A colon in a connection's name arrives escaped, and stays in the name.
    function test_nmcli_rows_keep_escaped_colons() {
        const rows = StatusIcons.nmcliRows("home\\:5G:802-11-wireless:yes\nwork vpn:vpn:no\n");
        compare(rows.length, 2);
        compare(rows[0], ["home:5G", "802-11-wireless", "yes"]);
        compare(rows[1], ["work vpn", "vpn", "no"]);
        compare(StatusIcons.nmcliRows("").length, 0);
    }

    function test_vpn_connections_are_vpn_and_wireguard_only() {
        const rows = StatusIcons.nmcliRows("wired:802-3-ethernet:yes\noffice:vpn:no\nwg0:wireguard:yes\n");
        const vpns = StatusIcons.vpnConnections(rows);
        compare(vpns.length, 2);
        compare(vpns[0].name, "office");
        compare(vpns[0].active, false);
        compare(vpns[1].type, "wireguard");
        compare(vpns[1].active, true);
    }

    // ---- glyphs: the same states in Material Symbols -----------------------

    function test_volume_glyph_follows_the_icon_thresholds() {
        compare(StatusIcons.volumeGlyph(0.8, true), "volume_off");
        compare(StatusIcons.volumeGlyph(0, false), "volume_off");
        compare(StatusIcons.volumeGlyph(0.2, false), "volume_mute");
        compare(StatusIcons.volumeGlyph(0.5, false), "volume_down");
        compare(StatusIcons.volumeGlyph(1.0, false), "volume_up");
        compare(StatusIcons.volumeGlyph(1.4, false), "volume_up");
    }

    function test_mic_glyph() {
        compare(StatusIcons.micGlyph(0.5, false), "mic");
        compare(StatusIcons.micGlyph(0.5, true), "mic_off");
        compare(StatusIcons.micGlyph(0, false), "mic_off");
    }

    function test_wifi_glyph_steps() {
        compare(StatusIcons.wifiGlyph(0), "signal_wifi_0_bar");
        compare(StatusIcons.wifiGlyph(0.2), "network_wifi_1_bar");
        compare(StatusIcons.wifiGlyph(0.4), "network_wifi_2_bar");
        compare(StatusIcons.wifiGlyph(0.7), "network_wifi_3_bar");
        compare(StatusIcons.wifiGlyph(0.9), "signal_wifi_4_bar");
    }

    function test_network_glyph_wired_wins_and_limited_shows() {
        compare(StatusIcons.networkGlyph({ wired: true, wifi: true, strength: 0.9 }), "lan");
        compare(StatusIcons.networkGlyph({ wired: true, connectivity: "Limited" }), "signal_disconnected");
        compare(StatusIcons.networkGlyph({ wifi: true, strength: 0.9, connectivity: "Portal" }), "signal_wifi_bad");
        compare(StatusIcons.networkGlyph({ wifi: true, strength: 0.9, connectivity: "Unknown" }), "signal_wifi_4_bar");
        compare(StatusIcons.networkGlyph({}), "signal_wifi_off");
    }

    function test_bluetooth_glyph() {
        compare(StatusIcons.bluetoothGlyph(false, 2), "bluetooth_disabled");
        compare(StatusIcons.bluetoothGlyph(true, 0), "bluetooth");
        compare(StatusIcons.bluetoothGlyph(true, 1), "bluetooth_connected");
    }

    // Either scale, as the theme-icon rule accepts.
    function test_battery_glyph_levels() {
        compare(StatusIcons.batteryGlyph(1, false), "battery_full");
        compare(StatusIcons.batteryGlyph(100, false), "battery_full");
        compare(StatusIcons.batteryGlyph(0.84, false), "battery_5_bar");
        compare(StatusIcons.batteryGlyph(84, false), "battery_5_bar");
        compare(StatusIcons.batteryGlyph(0.12, false), "battery_1_bar");
        compare(StatusIcons.batteryGlyph(0.05, false), "battery_alert");
    }

    function test_battery_glyph_charging() {
        compare(StatusIcons.batteryGlyph(0.05, true), "battery_charging_20");
        compare(StatusIcons.batteryGlyph(0.55, true), "battery_charging_50");
        compare(StatusIcons.batteryGlyph(0.85, true), "battery_charging_80");
        compare(StatusIcons.batteryGlyph(0.97, true), "battery_charging_full");
    }

    function test_profile_and_brightness_glyphs() {
        compare(StatusIcons.profileGlyph("PowerSaver"), "eco");
        compare(StatusIcons.profileGlyph("Performance"), "speed");
        compare(StatusIcons.profileGlyph("Balanced"), "balance");
        compare(StatusIcons.brightnessGlyph(0.2), "brightness_low");
        compare(StatusIcons.brightnessGlyph(0.5), "brightness_medium");
        compare(StatusIcons.brightnessGlyph(0.9), "brightness_high");
    }

    // Night Light wins while it is doing something, as the icon rule does.
    function test_brightness_panel_glyph() {
        compare(StatusIcons.brightnessPanelGlyph(0.9, true, "warm"), "nightlight");
        compare(StatusIcons.brightnessPanelGlyph(0.9, true, "suspended"), "bedtime_off");
        compare(StatusIcons.brightnessPanelGlyph(0.9, true, "day"), "brightness_high");
        compare(StatusIcons.brightnessPanelGlyph(0.9, false, "day"), "light_mode");
    }

    function test_muted_wins_over_any_volume() {
        compare(StatusIcons.volumeIcon(0.8, true), "audio-volume-muted");
        compare(StatusIcons.volumeIcon(0, false), "audio-volume-muted");
    }

    function test_volume_levels() {
        compare(StatusIcons.volumeIcon(0.1, false), "audio-volume-low");
        compare(StatusIcons.volumeIcon(0.5, false), "audio-volume-medium");
        compare(StatusIcons.volumeIcon(1.0, false), "audio-volume-high");
    }

    // Amplified output must never look like an ordinary loud one.
    function test_boosted_volume_is_marked() {
        compare(StatusIcons.volumeIcon(1.1, false), "audio-volume-high-warning");
        compare(StatusIcons.volumeIcon(1.5, false), "audio-volume-high-danger");
    }

    function test_mic_levels() {
        compare(StatusIcons.micIcon(0.5, true), "microphone-sensitivity-muted");
        compare(StatusIcons.micIcon(0.9, false), "microphone-sensitivity-high");
    }

    function test_wheel_steps_and_clamps() {
        compare(StatusIcons.stepVolume(0.5, 1, 5, 1.0), 0.55);
        compare(StatusIcons.stepVolume(0.5, -2, 5, 1.0), 0.4);
        compare(StatusIcons.stepVolume(0.98, 1, 5, 1.0), 1.0);
        compare(StatusIcons.stepVolume(0.02, -1, 5, 1.0), 0);
    }

    // A touchpad reports fractions of a notch; each must move the volume a
    // little rather than a whole step or nothing.
    function test_fractional_steps_round_to_a_percent() {
        compare(StatusIcons.stepVolume(0.5, 0.4, 5, 1.0), 0.52);
    }

    // Boosted elsewhere past the cap: scrolling down starts from where it is,
    // and scrolling up does not push it further.
    function test_volume_above_the_cap_is_not_snapped_down() {
        compare(StatusIcons.stepVolume(1.3, -1, 5, 1.0), 1.25);
        compare(StatusIcons.stepVolume(1.3, 1, 5, 1.0), 1.3);
    }

    function test_wifi_strength() {
        compare(StatusIcons.wifiIcon(0), "network-wireless-signal-none");
        compare(StatusIcons.wifiIcon(0.2), "network-wireless-signal-weak");
        compare(StatusIcons.wifiIcon(0.5), "network-wireless-signal-ok");
        compare(StatusIcons.wifiIcon(0.7), "network-wireless-signal-good");
        compare(StatusIcons.wifiIcon(0.95), "network-wireless-signal-excellent");
    }

    // With both up, the wired link is the one traffic goes through.
    function test_wired_wins_over_wifi() {
        compare(StatusIcons.networkIcon({ wired: true, wifi: true, strength: 0.9, connectivity: "Full" }),
                "network-wired-activated");
    }

    function test_limited_connectivity_is_shown() {
        compare(StatusIcons.networkIcon({ wired: true, connectivity: "Portal" }),
                "network-wired-activated-limited");
        compare(StatusIcons.networkIcon({ wifi: true, strength: 0.9, connectivity: "Limited" }),
                "network-limited");
    }

    // "Unknown" is what the check reports when it is switched off. That is not
    // a warning, or everyone who disabled the check would see one forever.
    function test_unknown_connectivity_is_not_a_warning() {
        compare(StatusIcons.networkIcon({ wifi: true, strength: 0.9, connectivity: "Unknown" }),
                "network-wireless-signal-excellent");
    }

    function test_nothing_connected() {
        compare(StatusIcons.networkIcon({}), "network-offline");
        compare(StatusIcons.networkIcon(null), "network-offline");
    }

    function test_link_speed() {
        compare(StatusIcons.linkSpeed(0), "");
        compare(StatusIcons.linkSpeed(100), "100 Mbit/s");
        compare(StatusIcons.linkSpeed(1000), "1 Gbit/s");
        compare(StatusIcons.linkSpeed(2500), "2.5 Gbit/s");
    }

    function test_bluetooth() {
        compare(StatusIcons.bluetoothIcon(false, 2), "network-bluetooth-inactive-symbolic");
        compare(StatusIcons.bluetoothIcon(true, 0), "network-bluetooth");
        compare(StatusIcons.bluetoothIcon(true, 1), "network-bluetooth-activated");
    }

    // Both scales are accepted; a full battery must never draw as empty.
    function test_battery_scale() {
        compare(StatusIcons.fraction(0.42), 0.42);
        compare(StatusIcons.fraction(42), 0.42);
        compare(StatusIcons.fraction(100), 1);
        compare(StatusIcons.fraction(0), 0);
        compare(StatusIcons.fraction(undefined), 0);
    }

    function test_battery_icon() {
        compare(StatusIcons.batteryIcon(1, false), "battery-100");
        compare(StatusIcons.batteryIcon(100, false), "battery-100");
        compare(StatusIcons.batteryIcon(0.04, false), "battery-000");
        compare(StatusIcons.batteryIcon(0.47, true), "battery-050-charging");
    }

    function test_profiles() {
        compare(StatusIcons.profileIcon("PowerSaver"), "battery-profile-powersave");
        compare(StatusIcons.profileIcon("Performance"), "battery-profile-performance");
        compare(StatusIcons.profileIcon("Balanced"), "battery-profile-balanced");
        compare(StatusIcons.profileLabel("PowerSaver"), "Power saver");
    }

    function test_percent() {
        compare(StatusIcons.percent(0.456), "46%");
        compare(StatusIcons.percent(-1), "0%");
    }

    // Zero is UPower for "unknown", never "0 min".
    function test_duration() {
        compare(StatusIcons.duration(0), "");
        compare(StatusIcons.duration(20), "1 min");
        compare(StatusIcons.duration(45 * 60), "45 min");
        compare(StatusIcons.duration(3600 + 5 * 60), "1 h 05 min");
        compare(StatusIcons.duration(2 * 3600 - 10), "2 h 00 min");
    }

    function test_track_time() {
        compare(StatusIcons.trackTime(0), "0:00");
        compare(StatusIcons.trackTime(187.6), "3:07");
        compare(StatusIcons.trackTime(3723), "1:02:03");
        compare(StatusIcons.trackTime(NaN), "0:00");
    }

    function player(bus, playing, title, artist) {
        return { bus: bus, playing: playing, title: title ?? "", artist: artist ?? "" };
    }

    // playerctld repeats another player; it must never be offered as one.
    function test_the_proxy_is_not_a_player() {
        const r = StatusIcons.pickPlayer([player("org.mpris.MediaPlayer2.playerctld", true, "Song"),
                                          player("org.mpris.MediaPlayer2.spotify", true, "Song")], "");
        compare(r.list, [1]);
        compare(r.current, 1);
    }

    // A browser and Plasma's integration for it report the same track.
    function test_the_same_track_twice_is_offered_once() {
        const r = StatusIcons.pickPlayer([player("chromium.instance1", false, "Talk", "Someone"),
                                          player("plasma-browser-integration", false, "Talk", "Someone"),
                                          player("vlc", false, "Film")], "");
        compare(r.list, [0, 2]);
    }

    // What the bus really showed: Chrome's own entry has the tab title and no
    // artist, so no title comparison can pair it with the integration's.
    // The integration's `kde:pid` names the process, and that is the pair.
    function test_the_integration_replaces_the_browser_it_speaks_for() {
        const chrome = player("org.mpris.MediaPlayer2.chromium.instance3434", false,
                              "Thermal Grizzly just blew my mind with this design... - YouTube", "");
        const pbi = player("org.mpris.MediaPlayer2.plasma-browser-integration", false,
                           "Thermal Grizzly just blew my mind with this design...", "JayzTwoCents");
        pbi.pid = 3434;
        const r = StatusIcons.pickPlayer([chrome, pbi], "");
        compare(r.list, [1]);
        compare(r.current, 1);
    }

    // A second browser window's process is not claimed, and stays.
    function test_an_unclaimed_browser_instance_stays() {
        const other = player("org.mpris.MediaPlayer2.chromium.instance999", false, "Elsewhere");
        const pbi = player("org.mpris.MediaPlayer2.plasma-browser-integration", false, "Here");
        pbi.pid = 3434;
        compare(StatusIcons.pickPlayer([other, pbi], "").list, [0, 1]);
    }

    // Entries with no track yet are never merged with each other.
    function test_untitled_players_are_all_kept() {
        compare(StatusIcons.pickPlayer([player("a", false), player("b", false)], "").list, [0, 1]);
    }

    function test_whatever_plays_is_shown() {
        const r = StatusIcons.pickPlayer([player("a", false, "x"), player("b", true, "y")], "");
        compare(r.current, 1);
    }

    function test_the_choice_wins_while_it_plays() {
        const r = StatusIcons.pickPlayer([player("a", true, "x"), player("b", true, "y")], "b");
        compare(r.current, 1);
    }

    // Starting music elsewhere follows the music...
    function test_music_elsewhere_beats_a_paused_choice() {
        const r = StatusIcons.pickPlayer([player("a", false, "x"), player("b", true, "y")], "a");
        compare(r.current, 1);
    }

    // ...but with nothing playing, the choice is remembered.
    function test_a_paused_choice_is_kept_when_nothing_plays() {
        const r = StatusIcons.pickPlayer([player("a", false, "x"), player("b", false, "y")], "b");
        compare(r.current, 1);
    }

    function texts(list) {
        return list.map(e => e.text);
    }

    function test_clipboard_newest_first() {
        let h = StatusIcons.clipboardAdd([], "a", 5);
        h = StatusIcons.clipboardAdd(h, "b", 5);
        compare(texts(h), ["b", "a"]);
    }

    // Copying something again moves it up; it is not listed twice.
    function test_clipboard_copying_again_moves_it_up() {
        const h = StatusIcons.clipboardAdd([{ text: "a" }, { text: "b" }, { text: "c" }], "c", 5);
        compare(texts(h), ["c", "a", "b"]);
    }

    function test_clipboard_is_capped() {
        const h = StatusIcons.clipboardAdd([{ text: "a" }, { text: "b" }, { text: "c" }], "d", 3);
        compare(texts(h), ["d", "a", "b"]);
    }

    function test_clipboard_preview_is_one_line() {
        compare(StatusIcons.clipboardPreview("  first\n\n  second\tthird ", 40), "first second third");
        compare(StatusIcons.clipboardPreview("abcdefghij", 5), "abcd…");
        compare(StatusIcons.clipboardPreview(null, 5), "");
    }

    // What Klipper really returned here: images as "▨ ..." text, and one
    // empty entry.
    function test_klipper_images_are_marked_and_empties_dropped() {
        const e = StatusIcons.klipperEntries(["hello", "", "▨ 1920x1080 PNG"]);
        compare(e.length, 2);
        compare(e[0].image, false);
        compare(e[1].image, true);
    }

    function test_no_players() {
        compare(StatusIcons.pickPlayer([], "").current, -1);
        compare(StatusIcons.pickPlayer(null, "x").current, -1);
    }

    // ---- brightness ------------------------------------------------------

    // The shape powerdevil replies with for an external monitor over DDC,
    // with the model name it carries replaced by a stand-in: what is under
    // test is the flattening, and the label is a string like any other.
    readonly property string external: '{"type":"a{sv}","data":[{"Brightness":{"type":"i","data":7500},'
        + '"IsInternal":{"type":"b","data":false},"Label":{"type":"s","data":"EXA Displays 27Q"},'
        + '"MaxBrightness":{"type":"i","data":10000}}]}'

    function test_bus_props_are_flattened() {
        compare(StatusIcons.busProps(JSON.parse(external).data).Label, "EXA Displays 27Q");
        compare(Object.keys(StatusIcons.busProps(null)).length, 0);
        compare(Object.keys(StatusIcons.busProps([])).length, 0);
    }

    function test_displays_are_read_one_per_line() {
        const d = StatusIcons.brightnessDisplays([`display0 ${external}`, ""]);
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
        compare(StatusIcons.brightnessDisplays(["display1 Failed to get", `display2 ${noRange}`, "lonely"]).length, 0);
    }

    function test_brightness_steps_in_percent_of_the_range() {
        compare(StatusIcons.stepBrightness(5000, 10000, 1, 5), 5500);
        compare(StatusIcons.stepBrightness(5000, 10000, -2, 5), 4000);
        compare(StatusIcons.stepBrightness(9800, 10000, 1, 5), 10000);
    }

    // A laptop panel with a range of 15 still moves, and in whole steps.
    function test_a_short_range_still_moves() {
        compare(StatusIcons.stepBrightness(7, 15, 1, 5), 8);
        compare(StatusIcons.stepBrightness(7, 15, -1, 5), 6);
    }

    // Scrolling down stops at 1%: the bottom of the range is a black screen
    // on some panels.
    function test_scrolling_never_reaches_black() {
        compare(StatusIcons.stepBrightness(300, 10000, -5, 5), 100);
        compare(StatusIcons.stepBrightness(1, 15, -1, 5), 1);
        compare(StatusIcons.brightnessFloor(10000), 100);
        compare(StatusIcons.brightnessFloor(15), 1);
    }

    // Dimmed below the floor elsewhere: scrolling down leaves it there
    // rather than brightening it, and scrolling up starts from where it is.
    function test_below_the_floor_is_not_snapped_up() {
        compare(StatusIcons.stepBrightness(0, 10000, -1, 5), 0);
        compare(StatusIcons.stepBrightness(0, 10000, 1, 5), 500);
    }

    function nl(props) {
        return Object.assign({ available: true, enabled: true, inhibited: false, currentTemperature: 6500 }, props);
    }

    function test_night_light_states() {
        compare(StatusIcons.nightLightState({}), "unavailable");
        compare(StatusIcons.nightLightState(nl({ available: false })), "unavailable");
        compare(StatusIcons.nightLightState(nl({ enabled: false })), "off");
        compare(StatusIcons.nightLightState(nl({ inhibited: true, currentTemperature: 4500 })), "suspended");
        compare(StatusIcons.nightLightState(nl({ currentTemperature: 4500 })), "warm");
        compare(StatusIcons.nightLightState(nl({})), "day");
    }

    // A day temperature set below neutral is a tinted screen in daylight.
    function test_a_warm_day_is_warm() {
        compare(StatusIcons.nightLightState(nl({ currentTemperature: 6000 })), "warm");
    }

    function test_night_light_label_gives_the_temperature() {
        compare(StatusIcons.nightLightLabel(nl({ currentTemperature: 4500 })), "Night Light · 4500 K");
        compare(StatusIcons.nightLightLabel(nl({ inhibited: true })), "Night Light is suspended");
    }

    // Night Light takes the panel icon while it tints, or while the user
    // holds it off; otherwise it is the brightness.
    function test_panel_icon() {
        compare(StatusIcons.brightnessPanelIcon(0.8, true, "day"), "brightness-high");
        compare(StatusIcons.brightnessPanelIcon(0.2, true, "off"), "brightness-low");
        compare(StatusIcons.brightnessPanelIcon(0.8, true, "warm"), "redshift-status-on");
        compare(StatusIcons.brightnessPanelIcon(0.8, true, "suspended"), "redshift-status-off");
        compare(StatusIcons.brightnessPanelIcon(0, false, "day"), "redshift-status-day");
    }

    // ---- keyboard --------------------------------------------------------

    // What KWin returned here: a(sss), one layout, no label of the user's.
    function test_layouts_as_kwin_gives_them() {
        const l = StatusIcons.keyboardLayouts([["us", "", "English (US)"], ["de", "", "German"], ["bad"]]);
        compare(l.length, 2);
        compare(l[1].long, "German");
        compare(StatusIcons.keyboardLayouts(null).length, 0);
    }

    function test_layout_label() {
        compare(StatusIcons.layoutLabel({ short: "us", display: "", long: "English (US)" }), "US");
        compare(StatusIcons.layoutLabel({ short: "ru", display: "Рус", long: "Russian" }), "Рус");
        compare(StatusIcons.layoutLabel(null), "");
    }

    function test_cycle_wraps_both_ways() {
        compare(StatusIcons.cycleIndex(2, 3, 1), 0);
        compare(StatusIcons.cycleIndex(0, 3, -1), 2);
        compare(StatusIcons.cycleIndex(1, 3, -4), 0);
        compare(StatusIcons.cycleIndex(-1, 3, 1), 1);
        compare(StatusIcons.cycleIndex(0, 0, 1), -1);
    }

    // ---- privacy ---------------------------------------------------------

    function link(from, to, app, active, source) {
        return {
            active: active !== false,
            source: Object.assign({ mediaClass: from, api: "", role: "" }, source ?? {}),
            target: { mediaClass: to, app: app }
        };
    }

    // The four link shapes that turn up together: a browser recording a
    // microphone (two links, one per channel), another shell reading the
    // speakers' monitor for a visualiser, and an interface's own split
    // feeding its virtual sources. Only the browser is recording anyone.
    function test_only_a_microphone_being_recorded_counts() {
        const r = StatusIcons.recorders([
            link("Audio/Source", "Stream/Input/Audio", "Google Chrome input"),
            link("Audio/Source", "Stream/Input/Audio", "Google Chrome input"),
            link("Audio/Sink", "Stream/Input/Audio", "another-shell"),
            link("Audio/Source/Internal", "Stream/Input/Audio/Internal", "alsa_input.Mic1.split")
        ]);
        compare(r.microphone, ["Google Chrome input"]);
        compare(r.camera, []);
    }

    // A stream opened and paused is not listening.
    function test_a_paused_link_is_not_recording() {
        compare(StatusIcons.recorders([link("Audio/Source", "Stream/Input/Audio", "App", false)]).microphone, []);
    }

    // A screencast is a Video/Source too; only a camera device counts.
    function test_a_camera_is_not_a_screencast() {
        const r = StatusIcons.recorders([
            link("Video/Source", "Stream/Input/Video", "Zoom", true, { api: "v4l2" }),
            link("Video/Source", "Stream/Input/Video", "OBS", true, { api: "libcamera" }),
            link("Video/Source", "Stream/Input/Video", "Meet", true, { role: "Camera" }),
            link("Video/Source", "Stream/Input/Video", "Screen share", true)
        ]);
        compare(r.camera, ["Meet", "OBS", "Zoom"]);
        compare(r.microphone, []);
    }

    function test_nothing_recording() {
        compare(StatusIcons.recorders(null).microphone, []);
        compare(StatusIcons.privacyTooltip(StatusIcons.recorders([]), false), "");
    }

    function test_privacy_tooltip() {
        const users = { microphone: ["Chrome", "Discord"], camera: ["Zoom"] };
        compare(StatusIcons.privacyTooltip(users, false),
                "Camera in use by Zoom\nMicrophone in use by Chrome, Discord");
        compare(StatusIcons.privacyTooltip({ microphone: ["Chrome"], camera: [] }, true),
                "Microphone in use by Chrome (muted)");
    }
}
