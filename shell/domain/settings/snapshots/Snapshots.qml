pragma Singleton

// How a restore point reads in a list. Its name is a timestamp and a label --
// `20260910-122741-before-renderer-quickshell` -- and shown whole, the
// timestamp took the room and the label, which is the part that says what it
// is, was the part cut short. So the label is the title and the time is said
// the way a person would say it. Pure, and a module of its own so the tests
// can load it.

import QtQuick

QtObject {
    id: root

    // `before-renderer-quickshell` -> "Before renderer quickshell". A name
    // with no label is still a restore point.
    function title(name) {
        const label = String(name ?? "")
            .replace(/^\d{8}-\d{6}/, "")
            .replace(/^-+/, "")
            .replace(/-+/g, " ")
            .trim();
        return label.length > 0 ? label.charAt(0).toUpperCase() + label.slice(1) : "Restore point";
    }

    // "Today, 20:05", "Yesterday, 20:05", "9 Sep, 20:05", or "9 Sep 2025, 20:05"
    // for another year. From `created`, and failing that from the name, which
    // carries the same moment.
    function when(created, name, now) {
        let d = created ? new Date(created) : new Date(NaN);
        if (isNaN(d.getTime())) {
            const m = /^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})/.exec(String(name ?? ""));
            if (!m)
                return "";
            d = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]);
        }
        const today = now ?? new Date();
        const days = Math.round((new Date(today.getFullYear(), today.getMonth(), today.getDate())
                                 - new Date(d.getFullYear(), d.getMonth(), d.getDate())) / 86400000);
        const time = Qt.formatTime(d, "HH:mm");
        if (days === 0)
            return `Today, ${time}`;
        if (days === 1)
            return `Yesterday, ${time}`;
        const date = d.getFullYear() === today.getFullYear()
            ? Qt.formatDate(d, "d MMM") : Qt.formatDate(d, "d MMM yyyy");
        return `${date}, ${time}`;
    }
}
