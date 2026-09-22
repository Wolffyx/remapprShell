pragma Singleton

// The rules for this shell's own notification popups, as pure functions.
//
// A leaf module with nothing from Quickshell in it, so qmltestrunner can load
// it: the timing of a popup is what people notice when it is wrong -- a
// critical one that vanishes, an ordinary one that never does -- so it is
// tested rather than trusted.

import QtQuick

QtObject {
    id: root

    readonly property int critical: 2

    // How long a popup stays, in ms, or 0 for until it is closed. The spec's
    // expire_timeout: 0 is never, a positive value is the application's own,
    // -1 is ours. A critical notification stays whatever it asks for, as
    // Plasma's do, and nothing flashes past faster than it can be read.
    function timeoutFor(urgency, expireTimeout, defaultMs) {
        if (Number(urgency) >= root.critical)
            return 0;
        const asked = Number(expireTimeout);
        if (asked === 0)
            return 0;
        if (Number.isFinite(asked) && asked > 0)
            return Math.max(asked, 1500);
        return Math.max(1500, Number(defaultMs) || 6000);
    }

    // Do-not-disturb holds back everything but critical notifications.
    function admits(dnd, urgency) {
        return !dnd || Number(urgency) >= root.critical;
    }

    // Which popups to draw, from [{ id, urgency }]: critical first, then the
    // newest (ids count up), at most `max`. A critical one is never pushed off
    // the screen by ordinary ones arriving after it.
    function arrange(items, max) {
        const list = (items ?? []).filter(x => x);
        list.sort((a, b) => ((Number(b.urgency) >= root.critical) - (Number(a.urgency) >= root.critical))
                            || (Number(b.id) - Number(a.id)));
        return list.slice(0, Math.max(0, max ?? 0));
    }

    // The ids whose time is up, from { id: deadline in ms } against `now`,
    // sparing the one under the pointer. A deadline of 0 is never.
    function due(deadlines, now, held) {
        const out = [];
        for (const key of Object.keys(deadlines ?? {})) {
            const at = Number(deadlines[key]);
            if (at > 0 && at <= now && String(key) !== String(held))
                out.push(Number(key));
        }
        return out;
    }

    // When the pointer leaves a popup it gets a moment more, rather than
    // vanishing the instant it is let go of.
    function released(deadline, now) {
        return Number(deadline) > 0 ? Math.max(Number(deadline), now + 2000) : 0;
    }

    // The history's index for a notification, so "Ask" can name it to `rmpr
    // ask --notification`. Looked up when asked rather than when the popup
    // appeared: the eavesdrop that fills the history and the server that
    // draws the popup see the same call, in either order. The history is
    // newest first, so the latest of two identical notifications is the one
    // found.
    function historyIndex(entries, n) {
        if (!n)
            return -1;
        return (entries ?? []).findIndex(e => e && e.appName === n.appName
                                          && e.summary === n.summary && e.body === n.body);
    }

    // Where popups appear: a corner, or the middle of the top or the bottom
    // edge. "auto" is the right-hand end of the panel's edge, beside the
    // clock, where Windows and Plasma put them; the top right when the panel
    // runs down a side.
    readonly property var corners: ["top-right", "top-left", "top-center", "bottom-right", "bottom-left", "bottom-center"]

    function corner(position, panelEdge) {
        if (root.corners.indexOf(position) >= 0)
            return position;
        return panelEdge === "bottom" ? "bottom-right" : "top-right";
    }

    // A body as plain text. Markup is not advertised, but not every
    // application asks before sending it, and the body is drawn as plain text
    // -- never as rich text a sender could fill with links or remote images.
    function plain(text) {
        return String(text ?? "")
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&#39;|&apos;/g, "'")
            .replace(/&amp;/g, "&")
            .trim();
    }

    // ---- what a notification points at -------------------------------------
    //
    // Two things live in the hints rather than in the spec's arguments, and
    // both are what a person means when they click a notification.
    //
    // `x-kde-urls` is every KDE application's "this is the file I am telling
    // you about" -- Spectacle's saved screenshot, a finished download, a
    // received file. It arrives as an array of strings, and as a single
    // string from senders that write it that way.
    //
    // `desktop-entry` is which application sent it, which is what Plasma
    // activates when a notification has nothing else to act on. Without that
    // fallback a click on a notification whose sender declared no `default`
    // action does nothing at all but close it -- which is the bug this was
    // written for.

    function urlsOf(hints) {
        const raw = hints?.["x-kde-urls"] ?? null;
        const list = Array.isArray(raw) ? raw : (raw ? [raw] : []);
        return list.map(u => String(u ?? "").trim())
                   .filter(u => u.startsWith("file://") || u.startsWith("/"))
                   .map(u => u.startsWith("/") ? `file://${u}` : u);
    }

    readonly property var pictureTypes: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "avif"]

    function isPicture(url) {
        const path = String(url ?? "").split("?")[0].toLowerCase();
        const dot = path.lastIndexOf(".");
        return dot > 0 && root.pictureTypes.indexOf(path.slice(dot + 1)) >= 0;
    }

    // The picture to draw at the size it was taken at, rather than as a
    // 20-pixel icon: a file this notification names that is an image. A
    // screenshot notification is the case that matters -- Spectacle sends no
    // image at all, only the path it saved to.
    //
    // Only a local file, and only one whose name ends in an image type: this
    // is a path chosen by whoever sent the notification, so it decides what
    // the shell loads.
    function pictureOf(hints) {
        const hinted = String(hints?.["image-path"] ?? hints?.["image_path"] ?? "").trim();
        const direct = hinted.startsWith("/") ? `file://${hinted}` : hinted;
        if (direct.startsWith("file://") && root.isPicture(direct))
            return direct;
        return root.urlsOf(hints).find(u => root.isPicture(u)) ?? "";
    }

    // What a click on the body should do, as { kind, value }:
    //
    //   action   the sender's own `default` action -- always first, because it
    //            is the one thing the sender asked for
    //   url      a file it named, opened the way the desktop opens files
    //   devices  a removable device was plugged in: Disks & Devices, where it
    //            can be mounted and opened
    //   displays a screen was plugged in: the display settings
    //   app      the application that sent it, raised or started
    //   none     nothing to act on; the click closes the popup
    function openTarget(notification, hints) {
        const actions = notification?.actions ?? [];
        return root.targetFor({
            action: actions.find(a => String(a?.identifier ?? "") === "default") ?? null,
            url: root.urlsOf(hints)[0] ?? "",
            eventId: hints?.["x-kde-eventId"] ?? "",
            icon: notification?.appIcon ?? "",
            desktopEntry: notification?.desktopEntry ?? ""
        });
    }

    // Senders that are services rather than applications. Plasma's own
    // notifications -- a device plugged in, a disk filling up -- come from
    // kded, and "open the application that sent it" started a second kded,
    // which is a click that does nothing anybody can see. That is what
    // clicking "USB Device Detected" was.
    readonly property var services: ["org.kde.kded6", "org.kde.kded5", "org.kde.plasmashell",
                                     "org.kde.kwin", "org.kde.ksmserver", "org.kde.kglobalaccel"]

    // KDE names what happened in `x-kde-eventId`. Plasma sends `deviceAdded`
    // both for a USB device and for a screen, and only the icon tells them
    // apart: the summary is translated.
    function targetFor(o) {
        if (o?.action)
            return { kind: "action", value: o.action };
        const url = String(o?.url ?? "");
        if (url)
            return { kind: "url", value: url };
        if (String(o?.eventId ?? "") === "deviceAdded")
            return /display|monitor|video/i.test(String(o?.icon ?? ""))
                ? { kind: "displays", value: "" }
                : { kind: "devices", value: "" };
        const entry = String(o?.desktopEntry ?? "").trim().replace(/\.desktop$/, "");
        if (entry && root.services.indexOf(entry) < 0)
            return { kind: "app", value: entry };
        return { kind: "none", value: "" };
    }

    // What to draw as the icon: the image the server made, else the
    // application's icon, by path or by name. Returns { kind: "image" |
    // "name", value }.
    //
    // An icon sent with `notify-send -i` arrives as image://icon/<name>,
    // measured, with the icon field itself empty. That is a name, and is
    // looked up as one: the image provider has no fallback, and a name the
    // theme lacks drew Qt's magenta checkerboard.
    function iconOf(image, appIcon) {
        const img = String(image ?? "");
        if (img.startsWith("image://icon/"))
            return { kind: "name", value: img.slice("image://icon/".length) || "dialog-information" };
        if (img)
            return { kind: "image", value: img };
        const icon = String(appIcon ?? "");
        if (icon.startsWith("file://"))
            return { kind: "image", value: icon };
        if (icon.startsWith("/"))
            return { kind: "image", value: `file://${icon}` };
        return { kind: "name", value: icon || "dialog-information" };
    }
}
