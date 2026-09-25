// Tests for which media players are offered and which one is shown, and for
// a track's time as the seek bar reads it.
//
// The bus lists more players than there are: a proxy that repeats another, a
// browser and Plasma's integration for it reporting one track twice. What the
// bus really showed is pinned here, so the list stays one entry per player.

import QtQuick
import QtTest
import qs.domain.status.icons

TestCase {
    name: "MediaPlayers"

    function test_track_time() {
        compare(MediaPlayers.trackTime(0), "0:00");
        compare(MediaPlayers.trackTime(187.6), "3:07");
        compare(MediaPlayers.trackTime(3723), "1:02:03");
        compare(MediaPlayers.trackTime(NaN), "0:00");
    }

    function player(bus, playing, title, artist) {
        return { bus: bus, playing: playing, title: title ?? "", artist: artist ?? "" };
    }

    // playerctld repeats another player; it must never be offered as one.
    function test_the_proxy_is_not_a_player() {
        const r = MediaPlayers.pickPlayer([player("org.mpris.MediaPlayer2.playerctld", true, "Song"),
                                           player("org.mpris.MediaPlayer2.spotify", true, "Song")], "");
        compare(r.list, [1]);
        compare(r.current, 1);
    }

    // A browser and Plasma's integration for it report the same track.
    function test_the_same_track_twice_is_offered_once() {
        const r = MediaPlayers.pickPlayer([player("chromium.instance1", false, "Talk", "Someone"),
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
        const r = MediaPlayers.pickPlayer([chrome, pbi], "");
        compare(r.list, [1]);
        compare(r.current, 1);
    }

    // A second browser window's process is not claimed, and stays.
    function test_an_unclaimed_browser_instance_stays() {
        const other = player("org.mpris.MediaPlayer2.chromium.instance999", false, "Elsewhere");
        const pbi = player("org.mpris.MediaPlayer2.plasma-browser-integration", false, "Here");
        pbi.pid = 3434;
        compare(MediaPlayers.pickPlayer([other, pbi], "").list, [0, 1]);
    }

    // Entries with no track yet are never merged with each other.
    function test_untitled_players_are_all_kept() {
        compare(MediaPlayers.pickPlayer([player("a", false), player("b", false)], "").list, [0, 1]);
    }

    function test_whatever_plays_is_shown() {
        const r = MediaPlayers.pickPlayer([player("a", false, "x"), player("b", true, "y")], "");
        compare(r.current, 1);
    }

    function test_the_choice_wins_while_it_plays() {
        const r = MediaPlayers.pickPlayer([player("a", true, "x"), player("b", true, "y")], "b");
        compare(r.current, 1);
    }

    // Starting music elsewhere follows the music...
    function test_music_elsewhere_beats_a_paused_choice() {
        const r = MediaPlayers.pickPlayer([player("a", false, "x"), player("b", true, "y")], "a");
        compare(r.current, 1);
    }

    // ...but with nothing playing, the choice is remembered.
    function test_a_paused_choice_is_kept_when_nothing_plays() {
        const r = MediaPlayers.pickPlayer([player("a", false, "x"), player("b", false, "y")], "b");
        compare(r.current, 1);
    }

    function test_no_players() {
        compare(MediaPlayers.pickPlayer([], "").current, -1);
        compare(MediaPlayers.pickPlayer(null, "x").current, -1);
    }
}
