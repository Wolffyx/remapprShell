pragma Singleton

// The few words the status widgets share: a fraction as a percentage, and a
// time left as hours and minutes.
//
// A singleton of its own because more than one subject says them -- the
// network's tooltip gives a signal's strength in the same words the volume
// gives a level -- and a subject reaching into another for its wording is how
// the two would come to say it differently.

import QtQuick

QtObject {
    id: root

    function percent(v) {
        return `${Math.round((v > 0 ? v : 0) * 100)}%`;
    }

    // Seconds to "1 h 05 min" or "45 min". Nothing for an unknown time, which
    // UPower reports as zero -- a battery is never "0 min" from anything.
    function duration(seconds) {
        if (!(seconds > 0))
            return "";
        let h = Math.floor(seconds / 3600);
        let m = Math.round((seconds - h * 3600) / 60);
        if (m === 60) {
            h += 1;
            m = 0;
        }
        if (h === 0)
            return `${Math.max(1, m)} min`;
        return `${h} h ${String(m).padStart(2, "0")} min`;
    }
}
