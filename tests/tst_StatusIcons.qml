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

    function test_no_players() {
        compare(StatusIcons.pickPlayer([], "").current, -1);
        compare(StatusIcons.pickPlayer(null, "x").current, -1);
    }
}
