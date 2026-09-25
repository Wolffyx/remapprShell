pragma Singleton

// What the media widgets show, as pure functions of what MPRIS reports: which
// players to offer and which one to show, and a track's time as a clock reads
// it.
//
// StatusIcons forwards to every function here, so a widget that asks it keeps
// working.

import QtQuick

QtObject {
    id: root

    // Which players to offer, and which one to show.
    //
    // `players` are plain descriptors -- { bus, playing, title, artist, pid }
    // -- in the order the bus lists them; the result is indices into that
    // list: { list, current }, current -1 when there is nothing.
    //
    // Some entries are not players of their own. playerctld is a proxy that
    // repeats whichever player it saw last. And a browser with Plasma's
    // integration appears twice: as itself (`...chromium.instance3434`, the
    // tab title with " - YouTube" on the end, no artist) and as the
    // integration, which says whose it is with `kde:pid` 3434 and carries the
    // clean title and the artist. The browser's own entry is dropped when the
    // integration claims its process -- the same rule Plasma's applet uses --
    // and, failing that, a track an earlier entry already offers is not
    // offered again.
    //
    // The one shown: the one the user chose, while it plays; otherwise
    // whatever is playing; otherwise the one the user chose; otherwise the
    // first. Starting something elsewhere follows the music, the way Plasma's
    // own applet does, without a paused choice being forgotten.
    function pickPlayer(players, chosen) {
        const all = players ?? [];
        const list = [];
        const seen = new Set();
        const claimed = new Set(all.filter(p => p && p.pid > 0).map(p => String(p.pid)));
        all.forEach((p, i) => {
            if (!p || String(p.bus ?? "").indexOf("playerctld") >= 0)
                return;
            const instance = /\.instance(\d+)$/.exec(String(p.bus ?? ""));
            if (instance && !(p.pid > 0) && claimed.has(instance[1]))
                return;
            const key = p.title ? `${p.title}\u0000${p.artist ?? ""}` : "";
            if (key && seen.has(key))
                return;
            if (key)
                seen.add(key);
            list.push(i);
        });
        const chosenAt = chosen ? list.find(i => all[i].bus === chosen) : undefined;
        const playingAt = list.find(i => all[i].playing);
        let current = -1;
        if (chosenAt !== undefined && all[chosenAt].playing)
            current = chosenAt;
        else if (playingAt !== undefined)
            current = playingAt;
        else if (chosenAt !== undefined)
            current = chosenAt;
        else if (list.length > 0)
            current = list[0];
        return { list: list, current: current };
    }

    // Seconds to "3:07", or "1:02:03" past the hour.
    function trackTime(seconds) {
        const s = Math.floor(seconds > 0 ? seconds : 0);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
    }
}
