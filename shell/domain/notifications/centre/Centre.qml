pragma Singleton

// How the notification centre arranges the history: grouped by application,
// or as one stream split into today, yesterday and earlier. Pure, and a module
// of its own so the tests can load it.
//
// Entries are NotificationWatch's -- { appName, appIcon, summary, body,
// urgency, when } -- newest first, and every arrangement keeps that order.

import QtQuick

QtObject {
    id: root

    function appOf(entry) {
        const a = String(entry?.appName ?? "").trim();
        return a.length > 0 ? a : "Notifications";
    }

    // [{ app, icon, entries }], the application heard from most recently
    // first. Its icon is the first one any of its entries brought.
    function groups(entries) {
        const out = [];
        const index = {};
        for (const e of entries ?? []) {
            if (!e)
                continue;
            const app = root.appOf(e);
            if (index[app] === undefined) {
                index[app] = out.length;
                out.push({ app: app, icon: "", entries: [] });
            }
            const g = out[index[app]];
            g.entries.push(e);
            if (!g.icon && e.appIcon)
                g.icon = e.appIcon;
        }
        return out;
    }

    function _day(t) {
        const d = new Date(t);
        return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
    }

    // [{ label, entries }]: "Today", "Yesterday", "Earlier", leaving out any
    // that would be empty.
    function buckets(entries, now) {
        const today = root._day(now);
        const yesterday = root._day(new Date(new Date(today).getFullYear(), new Date(today).getMonth(),
                                             new Date(today).getDate() - 1));
        const parts = [{ label: "Today", entries: [] }, { label: "Yesterday", entries: [] },
                       { label: "Earlier", entries: [] }];
        for (const e of entries ?? []) {
            if (!e)
                continue;
            const day = root._day(e.when ?? 0);
            parts[day >= today ? 0 : day >= yesterday ? 1 : 2].entries.push(e);
        }
        return parts.filter(p => p.entries.length > 0);
    }

    // "now", "5m", "3h", "2d": how long ago, as the design's cards say it.
    function ago(when, now) {
        const s = Math.max(0, Math.floor((now - (when ?? now)) / 1000));
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)}m`;
        if (s < 86400)
            return `${Math.floor(s / 3600)}h`;
        return `${Math.floor(s / 86400)}d`;
    }
}
