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

    // ---- pins ---------------------------------------------------------------

    // A pinned entry is never pushed off the end, and does not count
    // towards the cap: the cap is for what nobody asked to keep.
    function test_pinned_entries_are_never_capped_away() {
        const h = ClipboardHistory.clipboardAdd([{ text: "a", pinned: true }, { text: "b" }, { text: "c" }], "d", 2);
        compare(texts(h), ["d", "a", "b"]);
        compare(h[1].pinned, true);
    }

    // Copying a pinned thing again moves it up and keeps the pin.
    function test_copying_a_pinned_entry_keeps_the_pin() {
        const h = ClipboardHistory.clipboardAdd([{ text: "a" }, { text: "b", pinned: true }], "b", 5, 1000);
        compare(texts(h), ["b", "a"]);
        compare(h[0].pinned, true);
        compare(h[0].time, 1000);
    }

    function test_pin_toggles_and_clear_keeps_the_pinned() {
        let h = ClipboardHistory.clipboardAdd([], "a", 5);
        h = ClipboardHistory.clipboardAdd(h, "b", 5);
        h = ClipboardHistory.clipboardTogglePin(h, { text: "a", image: false });
        compare(h[1].pinned, true);
        compare(texts(ClipboardHistory.clipboardClear(h)), ["a"]);
        h = ClipboardHistory.clipboardTogglePin(h, { text: "a", image: false });
        compare(ClipboardHistory.clipboardClear(h), []);
    }

    // Removing one entry orphans its file and only its file.
    function test_remove_takes_one_entry_and_its_file() {
        let h = ClipboardHistory.clipboardAddImage([], "/tmp/a.png", 1, 1, 5);
        h = ClipboardHistory.clipboardAdd(h, "x", 5);
        const after = ClipboardHistory.clipboardRemove(h, h[1]);
        compare(texts(after), ["x"]);
        compare(ClipboardHistory.clipboardOrphans(h, after), ["/tmp/a.png"]);
    }

    // Choosing a picture copies it again, and the watcher hands it back as a
    // new file. That replaces the entry -- pin and all -- rather than
    // standing beside it, and the old file is the one to delete.
    function test_a_repicked_image_replaces_its_entry() {
        let h = ClipboardHistory.clipboardAddImage([], "/tmp/a.png", 4, 3, 5);
        h = ClipboardHistory.clipboardAdd(h, "x", 5);
        h = ClipboardHistory.clipboardTogglePin(h, h[1]);
        const after = ClipboardHistory.clipboardReplaceImage(h, "/tmp/a.png", "/tmp/b.png", 4, 3, 5, 7);
        compare(after.length, 2);
        compare(after[0].path, "/tmp/b.png");
        compare(after[0].pinned, true);
        compare(ClipboardHistory.clipboardOrphans(h, after), ["/tmp/a.png"]);
    }

    // ---- what an entry is ---------------------------------------------------

    function test_kinds_data() {
        return [
            { tag: "prose", text: "Group windows by application", kind: "text" },
            { tag: "number", text: "2.5 Gbit/s", kind: "text" },
            { tag: "sentence with a dash", text: "It works -- mostly.", kind: "text" },
            { tag: "hex", text: "#466fbd", kind: "colour" },
            { tag: "short hex", text: "#fff", kind: "colour" },
            { tag: "rgb", text: "rgb(70, 111, 189)", kind: "colour" },
            { tag: "link", text: "https://invent.kde.org/plasma/kwin", kind: "link" },
            { tag: "home path", text: "~/Projects/x/Widget.qml", kind: "path" },
            { tag: "absolute path", text: "/etc/fstab", kind: "path" },
            { tag: "slash alone", text: "/", kind: "text" },
            { tag: "code", text: "Keys.onUpPressed: move(-1)\nKeys.onDownPressed: move(1);", kind: "code" },
            { tag: "calls", text: "Keys.onUpPressed: win.move(-1)\nKeys.onReturnPressed: win.choose(win.index)", kind: "code" },
            { tag: "two lines of prose", text: "Dear all\nSee you there (on Friday)", kind: "text" },
            { tag: "known command", text: "journalctl --user -f", kind: "command" },
            { tag: "prompt", text: "$ make test", kind: "command" },
            { tag: "unknown with option", text: "rmpr reload --hard", kind: "command" },
            { tag: "pipe", text: "dmesg | tail", kind: "command" }
        ];
    }

    function test_kinds(data) {
        compare(ClipboardHistory.clipboardKind({ text: data.text, image: false }), data.kind);
    }

    function test_images_are_images() {
        compare(ClipboardHistory.clipboardKind({ text: "", image: true, path: "/tmp/a.png" }), "image");
        compare(ClipboardHistory.clipboardMeta({ image: true, path: "/tmp/a.png", width: 800, height: 600 }),
                "800×600 · PNG");
        // Klipper's say what they are after their mark.
        compare(ClipboardHistory.clipboardMeta({ image: true, text: "▨ 1920x1080 PNG" }), "1920x1080 PNG");
    }

    function test_meta() {
        compare(ClipboardHistory.clipboardMeta({ text: "abc" }), "3 characters");
        compare(ClipboardHistory.clipboardMeta({ text: "https://doc.qt.io/qt-6/x.html" }), "doc.qt.io");
        compare(ClipboardHistory.clipboardMeta({ text: "#466fbd" }), "rgb(70, 111, 189)");
        compare(ClipboardHistory.clipboardMeta({ text: "a {\n}\nb;" }), "3 lines");
    }

    // QML reads alpha first and no rgb() at all; CSS writes alpha last.
    function test_swatches_are_colours_qml_can_draw() {
        compare(ClipboardHistory.clipboardSwatch("#466FBD"), "#466fbd");
        compare(ClipboardHistory.clipboardSwatch("#abc"), "#aabbcc");
        compare(ClipboardHistory.clipboardSwatch("#11223380"), "#80112233");
        compare(Qt.colorEqual(ClipboardHistory.clipboardSwatch("rgb(255, 0, 0)"), "#ff0000"), true);
        compare(ClipboardHistory.clipboardSwatch("not a colour"), "transparent");
    }

    function test_age() {
        const now = 10 * 86400 * 1000;
        compare(ClipboardHistory.clipboardAge(0, now), "");
        compare(ClipboardHistory.clipboardAge(now - 5000, now), "now");
        compare(ClipboardHistory.clipboardAge(now - 4 * 60000, now), "4 min");
        compare(ClipboardHistory.clipboardAge(now - 2 * 3600000, now), "2 h");
        compare(ClipboardHistory.clipboardAge(now - 30 * 3600000, now), "yesterday");
        compare(ClipboardHistory.clipboardAge(now - 3 * 86400000, now), "3 d");
    }

    // ---- what a search finds ------------------------------------------------

    readonly property var sample: [
        { text: "make test", time: 5 },
        { text: "https://invent.kde.org/plasma/kwin", time: 4 },
        { text: "", image: true, path: "/tmp/a.png", width: 800, height: 600, time: 3 },
        { text: "#466fbd", pinned: true, time: 2 },
        { text: "Group windows by application", time: 1 }
    ]

    function test_find_puts_the_pinned_first() {
        compare(texts(ClipboardHistory.clipboardFind(sample, "all", "")),
                ["#466fbd", "make test", "https://invent.kde.org/plasma/kwin", "", "Group windows by application"]);
    }

    function test_find_by_filter() {
        compare(texts(ClipboardHistory.clipboardFind(sample, "links", "")), ["https://invent.kde.org/plasma/kwin"]);
        compare(ClipboardHistory.clipboardFind(sample, "images", "")[0].path, "/tmp/a.png");
        compare(texts(ClipboardHistory.clipboardFind(sample, "pinned", "")), ["#466fbd"]);
        compare(texts(ClipboardHistory.clipboardFind(sample, "text", "")),
                ["#466fbd", "make test", "Group windows by application"]);
    }

    // A search reads the text, what the entry is, and the line under it.
    function test_find_by_query() {
        compare(texts(ClipboardHistory.clipboardFind(sample, "all", "WINDOWS")), ["Group windows by application"]);
        compare(ClipboardHistory.clipboardFind(sample, "all", "800×600")[0].path, "/tmp/a.png");
        compare(texts(ClipboardHistory.clipboardFind(sample, "all", "command")), ["make test"]);
        compare(texts(ClipboardHistory.clipboardFind(sample, "all", "rgb(70")), ["#466fbd"]);
        compare(ClipboardHistory.clipboardFind(sample, "links", "windows"), []);
    }

    // ---- pins across a restart ----------------------------------------------

    // Only pinned entries are written down, and only what describes them.
    function test_pins_to_keep() {
        const kept = ClipboardHistory.clipboardPinsToKeep([
            { text: "a", pinned: true, time: 5, extra: "x" },
            { text: "b" },
            { image: true, path: "/s/1.png", width: 2, height: 3, pinned: true }
        ]);
        compare(kept.length, 2);
        compare(kept[0], { image: false, text: "a", time: 5, pinned: true });
        compare(kept[1].path, "/s/1.png");
        compare(kept[1].pinned, true);
    }

    // Read back first; a pin already in the history is not listed twice.
    function test_restore_pins() {
        const h = ClipboardHistory.clipboardRestorePins([{ text: "b" }, { text: "a" }],
                                                        [{ text: "a", pinned: true }, { text: "c" }]);
        compare(texts(h), ["a", "c", "b"]);
        verify(h[0].pinned && h[1].pinned);
        verify(!h[2].pinned);
    }

    // The file is read from disk: anything not the shape of an entry is
    // dropped, and a picture must be an absolute path to a .png.
    function test_restore_ignores_junk() {
        const h = ClipboardHistory.clipboardRestorePins([], [null, 3, "x", { text: "  " }, { text: 5 },
            { image: true, path: "relative.png" }, { image: true, path: "/etc/passwd" },
            { image: true, path: "/s/2.png" }]);
        compare(h.length, 1);
        compare(h[0].path, "/s/2.png");
        compare(ClipboardHistory.clipboardRestorePins([{ text: "a" }], { not: "a list" }).length, 1);
    }

    function test_counts() {
        compare(ClipboardHistory.clipboardCounts(sample),
                { all: 5, pinned: 1, text: 3, links: 1, images: 1 });
    }

    // What an earlier run left: its files, older than this start and not a
    // pin. This run's files, a pin's file and anything not named as the
    // watcher names its files stay.
    function test_stale_files() {
        const dir = "/s/clipboard";
        const names = ["1789573221204362735.png", "1789580551085237453.png", "1899999999999999999.png",
                       "notes.txt", "x.png", "123.png.tmp", "1789580792996470804.png"];
        const kept = [{ image: true, path: `${dir}/1789580551085237453.png`, pinned: true },
                      { text: "a" }];
        compare(ClipboardHistory.clipboardStale(names, dir, kept, "1800000000000000000"),
                [`${dir}/1789573221204362735.png`, `${dir}/1789580792996470804.png`]);
    }

    // A file from the very moment the run began is the run's own.
    function test_stale_is_strictly_earlier() {
        compare(ClipboardHistory.clipboardStale(["1800000000000000000.png", "999.png"], "/d", [],
                                                "1800000000000000000"), ["/d/999.png"]);
    }

    // No start time to compare against: nothing is stale.
    function test_stale_needs_a_start() {
        compare(ClipboardHistory.clipboardStale(["1.png"], "/d", [], ""), []);
        compare(ClipboardHistory.clipboardStale(["1.png"], "/d", [], undefined), []);
        compare(ClipboardHistory.clipboardStale(["1.png"], "/d", [], "12ab"), []);
        compare(ClipboardHistory.clipboardStale(undefined, "/d", [], "5"), []);
    }

    // Klipper's own rows: images point at Klipper's file, starred ones come
    // first, and ids that are not Klipper's are never made into a path.
    function test_klipper_store_entries() {
        const a = "a".repeat(40), b = "b".repeat(40), c = "c".repeat(40), d = "d".repeat(40);
        const rows = [
            { uuid: a, text: "hello", starred: 0, used: 1794510156.017, image: null },
            { uuid: b, text: null, starred: 0, used: 1794506551.5, image: d },
            { uuid: c, text: "kept", starred: 1, used: 1700000000, image: null },
            { uuid: "../../etc", text: "x", starred: 0, used: 1, image: null },
            { uuid: d, text: null, starred: 0, used: 2, image: "../passwd" },
            { uuid: d, text: "", starred: 0, used: 3, image: null },
            null
        ];
        const e = ClipboardHistory.klipperStoreEntries(rows, "/k/data");
        compare(e.length, 3);
        compare(e[0].text, "kept");
        compare(e[0].pinned, true);
        compare(e[1].text, "hello");
        compare(e[1].time, 1794510156017);
        compare(e[2].image, true);
        compare(e[2].path, `/k/data/${b}/${d}`);
        compare(ClipboardHistory.klipperStoreEntries(undefined, "/k"), []);
        compare(ClipboardHistory.klipperStoreEntries({}, "/k"), []);
    }
}
