pragma Singleton

// The clipboard history, as pure functions of the list it is: what copying
// something does to it, which image files fall out of it, what an entry says
// on one line, and Klipper's history read into the same shape.
//
// Pure, and apart from the watcher that owns the list, because one of these
// decides which files are deleted. StatusIcons forwards to every function
// here, so a widget that asks it keeps working.

import QtQuick

QtObject {
    id: root

    // A history with `text` at the top: an entry already in it moves up
    // rather than appearing twice, and the oldest fall off past `limit`.
    function clipboardAdd(list, text, limit) {
        const rest = (list ?? []).filter(e => e && e.text !== text);
        return [{ text: text, image: false }].concat(rest).slice(0, Math.max(1, limit));
    }

    // An image that was copied. The file is ours -- written by the watcher
    // into the cache -- so the same picture copied twice is two files, and the
    // older entry (with its file) falls off the end of the list like any
    // other. The path is carried rather than the pixels: a clipboard image is
    // megabytes, and QML holding several of them as data is a shell that grows
    // all day.
    function clipboardAddImage(list, path, width, height, limit) {
        const rest = (list ?? []).filter(e => e && e.path !== path);
        return [{ text: "", image: true, path: String(path), width: Number(width) || 0,
                  height: Number(height) || 0 }]
            .concat(rest).slice(0, Math.max(1, limit));
    }

    // The image files an old list has that a new one does not: what the
    // watcher deletes after the list is trimmed, so the cache cannot grow
    // without bound. Pure, because getting it wrong deletes a file.
    function clipboardOrphans(before, after) {
        const kept = new Set((after ?? []).filter(e => e && e.image).map(e => String(e.path)));
        return (before ?? []).filter(e => e && e.image && !kept.has(String(e.path)))
                             .map(e => String(e.path));
    }

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
