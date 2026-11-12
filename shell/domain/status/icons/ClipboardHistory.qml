pragma Singleton

// The clipboard history, as pure functions of the list it is: what copying
// something does to it, which image files fall out of it, what an entry says
// on one line, what kind of thing it is, what a search finds in it, and
// Klipper's history read into the same shape.
//
// Pure, and apart from the watcher that owns the list, because one of these
// decides which files are deleted. StatusIcons forwards to the older
// functions here, so a widget that asks it keeps working.
//
// An entry is { text, image, path?, width?, height?, pinned?, time? }. A
// pinned entry stays at the top, is never pushed off the end by newer ones,
// and survives clearing the history; `time` is when it was copied, in ms,
// and 0 when nobody knows (Klipper's).

import QtQuick

QtObject {
    id: root

    // What an entry is, one key per distinct thing: two copies of the same
    // text are one entry, and every picture is its own file.
    function clipboardKey(entry) {
        if (!entry)
            return "";
        return entry.image ? `image:${entry.path ?? entry.text ?? ""}` : `text:${entry.text ?? ""}`;
    }

    // `fresh` at the top of `list`, with whatever it replaces taken out. The
    // pin goes with it: copying a pinned thing again does not unpin it. Past
    // `limit`, the oldest unpinned entries fall off; pinned ones never do.
    function _push(list, fresh, limit) {
        const key = root.clipboardKey(fresh);
        const old = (list ?? []).find(e => e && root.clipboardKey(e) === key);
        const top = (old && old.pinned) ? Object.assign({}, fresh, { pinned: true }) : fresh;
        const rest = (list ?? []).filter(e => e && root.clipboardKey(e) !== key);
        const cap = Math.max(1, limit);
        let kept = 0;
        return [top].concat(rest).filter(e => e.pinned || ++kept <= cap);
    }

    // A history with `text` at the top: an entry already in it moves up
    // rather than appearing twice, and the oldest fall off past `limit`.
    function clipboardAdd(list, text, limit, now) {
        return root._push(list, { text: text, image: false, time: Number(now) || 0 }, limit);
    }

    // An image that was copied. The file is ours -- written by the watcher
    // into the cache -- so the same picture copied twice is two files, and the
    // older entry (with its file) falls off the end of the list like any
    // other. The path is carried rather than the pixels: a clipboard image is
    // megabytes, and QML holding several of them as data is a shell that grows
    // all day.
    function clipboardAddImage(list, path, width, height, limit, now) {
        return root._push(list, { text: "", image: true, path: String(path), width: Number(width) || 0,
                                  height: Number(height) || 0, time: Number(now) || 0 }, limit);
    }

    // A picture chosen from the history comes back through the watcher as a
    // new file of the same pixels. That is the entry that was chosen, not a
    // new one: it replaces the old entry at the top, keeping its pin, and
    // the old file falls out to be deleted.
    function clipboardReplaceImage(list, oldPath, path, width, height, limit, now) {
        const old = (list ?? []).find(e => e && e.image && e.path === oldPath);
        const next = root.clipboardAddImage(root.clipboardRemove(list, old), path, width, height, limit, now);
        if (!old || !old.pinned)
            return next;
        return root.clipboardTogglePin(next, next[0]);
    }

    // The history without `entry`.
    function clipboardRemove(list, entry) {
        const key = root.clipboardKey(entry);
        return (list ?? []).filter(e => e && root.clipboardKey(e) !== key);
    }

    // The history with `entry` pinned, or unpinned if it was.
    function clipboardTogglePin(list, entry) {
        const key = root.clipboardKey(entry);
        return (list ?? []).map(e => (e && root.clipboardKey(e) === key)
                                     ? Object.assign({}, e, { pinned: !e.pinned }) : e);
    }

    // What clearing leaves: the pinned entries, which are there because
    // somebody asked for them to stay.
    function clipboardClear(list) {
        return (list ?? []).filter(e => e && e.pinned);
    }

    // The image files an old list has that a new one does not: what the
    // watcher deletes after the list is trimmed, so the cache cannot grow
    // without bound. Pure, because getting it wrong deletes a file.
    function clipboardOrphans(before, after) {
        const kept = new Set((after ?? []).filter(e => e && e.image).map(e => String(e.path)));
        return (before ?? []).filter(e => e && e.image && e.path && !kept.has(String(e.path)))
                             .map(e => String(e.path));
    }

    // The image files in the clipboard folder that nothing can show again:
    // files the watcher wrote in an earlier run (or before a reload) whose
    // entries lived only in memory. `names` are the folder's file names,
    // `dir` the folder, `kept` the entries now in the history -- the pins
    // read back -- whose files stay, and `before` when this run started, in
    // nanoseconds since the epoch as a string of digits.
    //
    // Only the watcher's own names count: digits, the time it was written in
    // nanoseconds, then ".png". Anything else in the folder is not ours to
    // touch, and a file written at or after `before` belongs to this run --
    // a picture copied while the shell was starting. Pure, because getting it
    // wrong deletes a file. The times are compared as digit strings: they
    // are past what a JavaScript number holds exactly.
    function clipboardStale(names, dir, kept, before) {
        const cut = String(before ?? "");
        if (!/^\d+$/.test(cut))
            return [];
        const keep = new Set((kept ?? []).filter(e => e && e.image && e.path).map(e => String(e.path)));
        return (names ?? []).map(n => String(n))
            .filter(n => /^\d+\.png$/.test(n) && root._earlier(n.slice(0, -4), cut))
            .map(n => `${dir}/${n}`)
            .filter(p => !keep.has(p));
    }

    // Whether one string of digits is a smaller number than another.
    function _earlier(a, b) {
        if (a.length !== b.length)
            return a.length < b.length;
        return a < b;
    }

    // ---- what an entry is ---------------------------------------------------

    // Program names a copied line is a command for, when it carries no
    // option to say so itself.
    readonly property var _commands: ["sudo", "git", "make", "cd", "ls", "cp", "mv", "rm", "mkdir", "cat",
        "grep", "rg", "find", "systemctl", "journalctl", "pacman", "paru", "yay", "flatpak", "npm", "pnpm",
        "yarn", "cargo", "python", "python3", "pip", "ssh", "scp", "curl", "wget", "docker", "podman",
        "kubectl", "qdbus", "gdbus", "kwriteconfig6", "kreadconfig6", "quickshell", "qs", "wl-copy",
        "wl-paste", "nix", "apt", "dnf", "zypper"]

    // In order: the first that matches names the entry. Each sees the text
    // trimmed, and how many lines it has.
    readonly property var _kinds: [
        { kind: "colour", test: (t, lines) => lines === 1
            && /^(#([0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})|rgba?\([\d\s.,%]+\)|hsla?\([\d\s.,%deg]+\))$/i.test(t) },
        { kind: "link", test: (t, lines) => lines === 1 && /^(https?|ftp|file):\/\/\S+$/i.test(t) },
        { kind: "path", test: (t, lines) => lines === 1 && t.length > 1 && /^(~|\.{1,2})?\/[^\s]*$/.test(t) },
        // Braces, semicolons, assignments, indentation, or a call: name(
        // with nothing between -- which prose with a remark in brackets
        // does not have.
        { kind: "code", test: (t, lines) => lines > 1 && /[{};=]|^\s{2,}\S|\w\(/m.test(t) },
        { kind: "command", test: (t, lines) => lines === 1 && t.length <= 300 && root._isCommand(t) }
    ]

    function _isCommand(t) {
        const first = t.replace(/^\$\s+/, "").split(/\s+/)[0];
        if (t.startsWith("$ ") || root._commands.indexOf(first) >= 0)
            return true;
        // A word and then an option or a pipe, and nothing that reads as prose.
        return /^[a-z0-9_.-]+\s(.*\s)?(--?[a-z]|[|&>])/i.test(t) && !/[.?!]$/.test(t);
    }

    // "text", "code", "command", "path", "colour", "link" or "image".
    function clipboardKind(entry) {
        if (!entry)
            return "text";
        if (entry.image)
            return "image";
        const t = String(entry.text ?? "").trim();
        const lines = t.split("\n").length;
        const hit = root._kinds.find(k => k.test(t, lines));
        return hit ? hit.kind : "text";
    }

    // Which filter a kind is found under, besides "all" and "pinned".
    readonly property var _groups: ({ text: "text", code: "text", command: "text", path: "text",
                                      colour: "text", link: "links", image: "images" })

    readonly property var _labels: ({ text: "Text", code: "Code", command: "Command", path: "File path",
                                      colour: "Colour", link: "Link", image: "Image" })

    readonly property var _glyphs: ({ text: "notes", code: "code", command: "terminal", path: "description",
                                      colour: "palette", link: "link", image: "image" })

    // Monospaced in the preview: the kinds where a character's place matters.
    readonly property var _mono: ({ code: true, command: true, path: true, colour: true })

    function clipboardKindLabel(kind) { return root._labels[kind] ?? "Text"; }
    function clipboardKindGlyph(kind) { return root._glyphs[kind] ?? "notes"; }
    function clipboardKindMono(kind) { return root._mono[kind] === true; }

    // The address without its scheme or path: what a link is, at a glance.
    function clipboardHost(url) {
        return String(url ?? "").trim().replace(/^[a-z]+:\/\//i, "").split(/[/?#]/)[0];
    }

    // "#466fbd" as "rgb(70, 111, 189)"; anything else as it is.
    function clipboardRgb(colour) {
        const t = String(colour ?? "").trim();
        const m = /^#([0-9a-f]{6})$/i.exec(t);
        if (!m)
            return t;
        const n = parseInt(m[1], 16);
        return `rgb(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255})`;
    }

    // A copied colour as one QML can draw: CSS writes alpha last
    // ("#rrggbbaa"), Qt first ("#aarrggbb"), and Qt reads no rgb() at all.
    // "transparent" for anything that is not a colour.
    function clipboardSwatch(colour) {
        const t = String(colour ?? "").trim().toLowerCase();
        const hex = /^#([0-9a-f]{3,8})$/.exec(t);
        if (hex)
            return root._hexSwatch(hex[1]);
        const fn = /^(rgb|hsl)a?\(([^)]*)\)$/.exec(t);
        if (!fn)
            return "transparent";
        const n = fn[2].split(/[\s,\/]+/).filter(x => x.length > 0).map(x => parseFloat(x));
        if (n.length < 3 || n.some(x => isNaN(x)))
            return "transparent";
        const a = n.length > 3 ? (fn[2].indexOf("%") >= 0 && n[3] > 1 ? n[3] / 100 : n[3]) : 1;
        if (fn[1] === "rgb")
            return Qt.rgba(n[0] / 255, n[1] / 255, n[2] / 255, a);
        return Qt.hsla(((n[0] % 360) + 360) % 360 / 360, n[1] / 100, n[2] / 100, a);
    }

    function _hexSwatch(h) {
        const full = h.length <= 4 ? h.split("").map(c => c + c).join("") : h;
        if (full.length === 6)
            return `#${full}`;
        if (full.length === 8)
            return `#${full.slice(6)}${full.slice(0, 6)}`;
        return "transparent";
    }

    function _imageMeta(e) {
        if (e.width > 0 && e.height > 0)
            return `${e.width}×${e.height} · PNG`;
        // Klipper's: what it wrote after its "▨".
        const said = String(e.text ?? "").replace(/^▨\s*/, "").trim();
        return said.length > 0 ? said : "Picture";
    }

    readonly property var _meta: ({
        text: e => { const n = String(e.text ?? "").length; return n === 1 ? "1 character" : `${n} characters`; },
        code: e => `${String(e.text ?? "").trim().split("\n").length} lines`,
        command: () => "Command",
        path: () => "File path",
        colour: e => root.clipboardRgb(e.text),
        link: e => root.clipboardHost(e.text),
        image: e => root._imageMeta(e)
    })

    // The line under an entry's own: what it is, in a few words.
    function clipboardMeta(entry) {
        if (!entry)
            return "";
        return root._meta[root.clipboardKind(entry)](entry);
    }

    // How long ago, shortly: "now", "4 min", "2 h", "yesterday", "3 d". Empty
    // when nobody knows.
    function clipboardAge(time, now) {
        if (!(time > 0))
            return "";
        const s = Math.max(0, Math.floor((now - time) / 1000));
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)} min`;
        if (s < 86400)
            return `${Math.floor(s / 3600)} h`;
        return s < 172800 ? "yesterday" : `${Math.floor(s / 86400)} d`;
    }

    // ---- what a search finds ------------------------------------------------

    function _inFilter(entry, filter) {
        if (filter === "all")
            return true;
        if (filter === "pinned")
            return !!entry.pinned;
        return root._groups[root.clipboardKind(entry)] === filter;
    }

    // Whether `entry` has `query` in its text, what it is or the line under
    // it -- so "png", "link" and "kde.org" all find something.
    function clipboardMatches(entry, query) {
        const q = String(query ?? "").trim().toLowerCase();
        if (q.length === 0)
            return true;
        const kind = root.clipboardKind(entry);
        const hay = [entry.text ?? "", root.clipboardKindLabel(kind), root.clipboardMeta(entry)].join(" ").toLowerCase();
        return hay.indexOf(q) >= 0;
    }

    // What the list shows for a filter ("all", "pinned", "text", "links",
    // "images") and a search: the pinned first, each part newest first.
    function clipboardFind(list, filter, query) {
        const hits = (list ?? []).filter(e => e && root._inFilter(e, filter ?? "all")
                                              && root.clipboardMatches(e, query));
        return hits.filter(e => e.pinned).concat(hits.filter(e => !e.pinned));
    }

    // How many each filter would show, before any search.
    function clipboardCounts(list) {
        const all = (list ?? []).filter(e => e);
        const count = f => all.filter(e => root._inFilter(e, f)).length;
        return { all: all.length, pinned: count("pinned"), text: count("text"), links: count("links"),
                 images: count("images") };
    }

    // ---- pins across a restart ----------------------------------------------

    // How many pins are written down. A list of a few is what pinning is
    // for; the cap is there so a file that grew by mistake stays small.
    readonly property int pinsKept: 100

    // What is written down so the pins outlive the shell: the pinned entries
    // and only the fields that describe them, in the order they are listed.
    function clipboardPinsToKeep(list) {
        return (list ?? [])
            .filter(e => e && e.pinned)
            .slice(0, root.pinsKept)
            .map(e => e.image
                ? { image: true, text: "", path: String(e.path ?? ""), width: Number(e.width) || 0,
                    height: Number(e.height) || 0, time: Number(e.time) || 0, pinned: true }
                : { image: false, text: String(e.text ?? ""), time: Number(e.time) || 0, pinned: true });
    }

    // One entry read back from the file, or null when it is not one: a
    // picture needs an absolute path to a .png, text needs words. Read from
    // disk, so nothing in it is trusted to be the shape it should be.
    function _restored(e) {
        if (!e || typeof e !== "object")
            return null;
        if (e.image === true) {
            const path = String(e.path ?? "");
            if (!path.startsWith("/") || !path.endsWith(".png"))
                return null;
            return { image: true, text: "", path: path, width: Number(e.width) || 0,
                     height: Number(e.height) || 0, time: Number(e.time) || 0, pinned: true };
        }
        const text = typeof e.text === "string" ? e.text : "";
        return text.trim().length > 0 ? { image: false, text: text, time: Number(e.time) || 0, pinned: true } : null;
    }

    // The history with the pins read back put first. Anything already in the
    // history is not listed twice: the pinned copy stands for it.
    function clipboardRestorePins(list, saved) {
        const pins = (Array.isArray(saved) ? saved : []).slice(0, root.pinsKept)
            .map(e => root._restored(e)).filter(e => e !== null);
        const keys = new Set(pins.map(e => root.clipboardKey(e)));
        const rest = (list ?? []).filter(e => e && !keys.has(root.clipboardKey(e)));
        return pins.concat(rest);
    }

    // ---- one line -----------------------------------------------------------

    // What an entry says on one line, whether it is text or a picture.
    function clipboardLabel(entry, max) {
        if (!entry)
            return "";
        if (entry.image) {
            const size = (entry.width > 0 && entry.height > 0) ? ` · ${entry.width}×${entry.height}` : "";
            return `Image${size}`;
        }
        return root.clipboardPreview(entry.text, max);
    }

    // One line to show for an entry: runs of whitespace, newlines included,
    // collapsed to a space, and cut at `max` characters.
    function clipboardPreview(text, max) {
        const one = String(text ?? "").replace(/\s+/g, " ").trim();
        return one.length > max ? `${one.slice(0, Math.max(1, max - 1))}…` : one;
    }

    // Klipper's history as it keeps it on disk (Plasma 6, history3.sqlite,
    // database version 3): one row per entry, `uuid` naming it, `text`, the
    // `starred` flag, `used` -- when it was last used or else added, in
    // seconds -- and `image`, the id of its PNG where it has one. The PNG is
    // the file `<dataDir>/<uuid>/<image>`, Klipper's own copy, which is what
    // makes an image in Klipper's history something that can be chosen:
    // wl-copy reads it as it reads ours, and no second copy is made.
    //
    // Both ids are 40 hex digits as Klipper writes them, and anything else is
    // dropped rather than put into a path. Starred entries first, as pinned
    // ones are in ours, then newest first. Pure: rows are read off disk and
    // not trusted to be the shape of a row.
    function klipperStoreEntries(rows, dataDir) {
        const id = /^[0-9a-f]{40}$/;
        const entries = (Array.isArray(rows) ? rows : [])
            .filter(r => r && id.test(String(r.uuid ?? "")))
            .map(r => root._klipperRow(r, dataDir, id))
            .filter(e => e !== null);
        return entries.filter(e => e.pinned).concat(entries.filter(e => !e.pinned));
    }

    function _klipperRow(r, dataDir, id) {
        const time = Math.round((Number(r.used) || 0) * 1000);
        const pinned = Number(r.starred) === 1;
        const image = String(r.image ?? "");
        if (id.test(image))
            return { text: "", image: true, path: `${dataDir}/${r.uuid}/${image}`, pinned: pinned, time: time };
        const text = typeof r.text === "string" ? r.text : "";
        return text.length > 0 ? { text: text, image: false, pinned: pinned, time: time } : null;
    }

    // Klipper's history, as its DBus interface gives it: a list of strings,
    // where an image is a text that starts with "▨". An image cannot be put
    // back on the clipboard as text, so it is marked rather than offered.
    // Empty entries are dropped.
    function klipperEntries(items) {
        return (items ?? [])
            .filter(s => typeof s === "string" && s.length > 0)
            .map(s => ({ text: s, image: s.charAt(0) === "▨" }));
    }
}
