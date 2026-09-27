// Tests for the clipboard history: what copying does to the list, which image
// files fall out of it, and what an entry says on one line.
//
// One of these decides which files are deleted, which is why it is a pure
// function and why it is pinned here rather than trusted to the watcher.

import QtQuick
import QtTest
import qs.domain.status.icons

TestCase {
    name: "ClipboardHistory"

    function texts(list) {
        return list.map(e => e.text);
    }

    function test_clipboard_newest_first() {
        let h = ClipboardHistory.clipboardAdd([], "a", 5);
        h = ClipboardHistory.clipboardAdd(h, "b", 5);
        compare(texts(h), ["b", "a"]);
    }

    // Copying something again moves it up; it is not listed twice.
    function test_clipboard_copying_again_moves_it_up() {
        const h = ClipboardHistory.clipboardAdd([{ text: "a" }, { text: "b" }, { text: "c" }], "c", 5);
        compare(texts(h), ["c", "a", "b"]);
    }

    function test_clipboard_is_capped() {
        const h = ClipboardHistory.clipboardAdd([{ text: "a" }, { text: "b" }, { text: "c" }], "d", 3);
        compare(texts(h), ["d", "a", "b"]);
    }

    // An image is kept as a file, and the file has to be deleted when the
    // entry falls off the end -- so what to delete is worked out here, where
    // it can be tested, rather than inside the watcher that does the deleting.
    function test_clipboard_images_are_files() {
        let h = ClipboardHistory.clipboardAddImage([], "/tmp/a.png", 800, 600, 2);
        compare(h[0].image, true);
        compare(h[0].path, "/tmp/a.png");
        compare(ClipboardHistory.clipboardLabel(h[0], 40), "Image · 800×600");

        h = ClipboardHistory.clipboardAddImage(h, "/tmp/b.png", 0, 0, 2);
        compare(h.length, 2);
        compare(ClipboardHistory.clipboardLabel(h[0], 40), "Image");

        // Past the cap, the oldest goes -- and its file with it.
        const before = h;
        const after = ClipboardHistory.clipboardAddImage(h, "/tmp/c.png", 1, 1, 2);
        compare(after.length, 2);
        compare(ClipboardHistory.clipboardOrphans(before, after), ["/tmp/a.png"]);
        // Clearing the history orphans every file.
        compare(ClipboardHistory.clipboardOrphans(after, []), ["/tmp/c.png", "/tmp/b.png"]);
        // Text entries own no files.
        compare(ClipboardHistory.clipboardOrphans([{ text: "a", image: false }], []), []);
    }

    function test_clipboard_label_falls_back_to_the_text() {
        compare(ClipboardHistory.clipboardLabel({ text: "hello there", image: false }, 40), "hello there");
        compare(ClipboardHistory.clipboardLabel(null, 40), "");
    }

    function test_clipboard_preview_is_one_line() {
        compare(ClipboardHistory.clipboardPreview("  first\n\n  second\tthird ", 40), "first second third");
        compare(ClipboardHistory.clipboardPreview("abcdefghij", 5), "abcd…");
        compare(ClipboardHistory.clipboardPreview(null, 5), "");
    }

    // What Klipper really returned here: images as "▨ ..." text, and one
    // empty entry.
    function test_klipper_images_are_marked_and_empties_dropped() {
        const e = ClipboardHistory.klipperEntries(["hello", "", "▨ 1920x1080 PNG"]);
        compare(e.length, 2);
        compare(e[0].image, false);
        compare(e[1].image, true);
    }
}
