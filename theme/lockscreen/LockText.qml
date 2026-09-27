/*
    SPDX-License-Identifier: GPL-3.0-or-later

    How the lock screen says a length of time.

    "2 h 28 min" was worked out in five places -- the battery's time left, how
    long ago the screen locked, how long a phase of the day has left -- two of
    them counting in minutes and three in milliseconds. The arithmetic is here
    now, where the tests can read it. The wording stays each style's own: some
    say "1 h" on the hour and some "1 h 0 min", and `dropZero` is that choice.
*/
pragma Singleton

import QtQuick

QtObject {
    id: words

    // "40 min", "2 h 28 min", rounded to the minute. On the hour it is
    // "2 h", or "2 h 0 min" with `dropZero` false.
    function duration(ms: real, dropZero: bool): string {
        const m = Math.round(ms / 60000);
        if (m < 60)
            return m + " min";
        const h = Math.floor(m / 60), r = m % 60;
        return r > 0 || !dropZero ? h + " h " + r + " min" : h + " h";
    }

    // How long before `now` the moment `since` was, in whole minutes gone by:
    // "just now" for the first of them, then "12 min ago".
    function ago(since: date, now: date, dropZero: bool): string {
        const m = Math.floor((now.getTime() - since.getTime()) / 60000);
        return m < 1 ? "just now" : words.duration(m * 60000, dropZero) + " ago";
    }

    // Two digits, as a clock draws them.
    function pad(n: int): string {
        return String(n).padStart(2, "0");
    }
}
