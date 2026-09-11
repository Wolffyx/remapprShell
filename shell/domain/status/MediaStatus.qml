pragma Singleton

// What is playing, through MPRIS.
//
// Every player that speaks MPRIS -- browsers, Spotify, VLC, mpv with its
// plugin -- is reachable the same way, and Plasma's own media applet reads the
// same thing. Which of several players to show is decided by a pure function
// (StatusIcons.pickPlayer), so the rule is tested rather than trusted.

import QtQuick
import Quickshell.Services.Mpris
import qs.domain.status.icons

QtObject {
    id: root

    readonly property var all: Mpris.players?.values ?? []

    // The player the user picked from the popout, by bus name. Held only while
    // the shell runs; which player matters is a question for the moment.
    property string chosen: ""

    readonly property var picked: StatusIcons.pickPlayer(root.all.map(p => ({
        bus: p?.dbusName ?? "",
        playing: p?.isPlaying ?? false,
        title: p?.trackTitle ?? "",
        artist: p?.trackArtist ?? "",
        // Set by Plasma's browser integration: the browser process it speaks for.
        pid: Number(p?.metadata?.["kde:pid"] ?? 0)
    })), root.chosen)

    readonly property var players: root.picked.list.map(i => root.all[i])
    readonly property var current: root.picked.current >= 0 ? root.all[root.picked.current] : null

    readonly property bool present: !!root.current
    readonly property bool playing: root.current?.isPlaying ?? false

    readonly property string title: root.current?.trackTitle || root.current?.identity || ""
    readonly property string artist: root.current?.trackArtist ?? ""

    function choose(player) {
        root.chosen = player?.dbusName ?? "";
    }

    function toggle() {
        if (root.current?.canTogglePlaying)
            root.current.togglePlaying();
    }

    function next() {
        if (root.current?.canGoNext)
            root.current.next();
    }

    function previous() {
        if (root.current?.canGoPrevious)
            root.current.previous();
    }

    function seek(seconds) {
        if (root.current?.canSeek && root.current?.positionSupported)
            root.current.position = Math.max(0, seconds);
    }

    function summary() {
        return {
            present: root.present,
            playing: root.playing,
            title: root.title,
            artist: root.artist,
            player: root.current?.identity ?? "",
            position: root.current?.position ?? 0,
            length: root.current?.length ?? 0,
            players: root.players.map(p => p?.identity ?? "")
        };
    }

    // MPRIS does not announce the position as it moves -- a player says where
    // it is only when asked -- so it is asked once a second while playing.
    // Emitting the change signal is how Quickshell is told to ask.
    readonly property Timer _tick: Timer {
        running: root.playing && (root.current?.positionSupported ?? false)
        interval: 1000
        repeat: true
        onTriggered: root.current?.positionChanged()
    }
}
