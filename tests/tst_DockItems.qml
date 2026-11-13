// Tests for what the dock shows and when it steps aside.

import QtQuick
import QtTest
import qs.domain.dock

TestCase {
    name: "DockItems"

    function keys(list) {
        return list.map(i => i.key);
    }

    readonly property var apps: [
        { key: "firefox", appKey: "firefox", windows: [] },
        { key: "org.kde.konsole", appKey: "org.kde.konsole", windows: [{ uuid: "u" }] },
        { key: "class:steam", appKey: "", windows: [{ uuid: "v" }] }
    ]

    // The start button, the applications in the order given, the places.
    function test_everything() {
        const all = DockItems.items(apps, { pinned: ["firefox"], places: true, downloads: "/home/u/Downloads" });
        compare(keys(all), ["launcher", "firefox", "org.kde.konsole", "class:steam", "divider", "downloads", "trash"]);
        compare(all[1].kind, "app");
        compare(all[5].uri, "file:///home/u/Downloads");
        compare(all[6].uri, "trash:/");
    }

    // Running applications that are not pinned can be left off.
    function test_pinned_only() {
        const pinned = DockItems.items(apps, { pinned: ["firefox"], running: false, launcher: false });
        compare(keys(pinned), ["firefox"]);
    }

    // Without a Downloads folder, the Trash alone.
    function test_places_without_downloads() {
        compare(keys(DockItems.places("")), ["divider", "trash"]);
    }

    function test_toggle_pin() {
        compare(DockItems.togglePin(["a", "b"], "c"), ["a", "b", "c"]);
        compare(DockItems.togglePin(["a", "b"], "a"), ["b"]);
        compare(DockItems.togglePin(undefined, "a"), ["a"]);
        compare(DockItems.togglePin(["a"], ""), ["a"]);
    }

    // launcher, a b c (kept), x y (running), the places.
    function dock() {
        return DockItems.items([
            { key: "a", appKey: "a", windows: [] },
            { key: "b", appKey: "b", windows: [] },
            { key: "c", appKey: "c", windows: [] },
            { key: "x", appKey: "x", windows: [{ uuid: "1" }] },
            { key: "y", appKey: "y", windows: [{ uuid: "2" }] },
            { key: "class:z", appKey: "", windows: [{ uuid: "3" }] }
        ], { pinned: ["a", "b", "c"], places: true, downloads: "/d" });
    }

    function test_drop_range_is_the_applications() {
        compare(DockItems.dropRange(dock()), [1, 6]);
        compare(DockItems.dropRange(DockItems.places("/d")), [-1, -1]);
        compare(DockItems.dropRange([]), [-1, -1]);
    }

    function test_draggable() {
        const d = dock();
        verify(!DockItems.draggable(d[0]));
        verify(DockItems.draggable(d[1]));
        verify(!DockItems.draggable(d[6]));
        verify(!DockItems.draggable(d[7]));
        verify(!DockItems.draggable(null));
    }

    // Kept applications take their new order.
    function test_reorder_kept() {
        compare(DockItems.reorder(dock(), ["a", "b", "c"], 1, 3), ["b", "c", "a"]);
        compare(DockItems.reorder(dock(), ["a", "b", "c"], 3, 1), ["c", "a", "b"]);
    }

    // A running application dropped among the kept ones, or just after
    // them, is kept from then on; one moved among the running is not.
    function test_reorder_running_joins() {
        compare(DockItems.reorder(dock(), ["a", "b", "c"], 4, 2), ["a", "x", "b", "c"]);
        compare(DockItems.reorder(dock(), ["a", "b", "c"], 5, 4), ["a", "b", "c", "y"]);
        compare(DockItems.reorder(dock(), ["a", "b", "c"], 4, 5), null);
    }

    // A kept one dropped among the running stays kept, last.
    function test_reorder_kept_into_running() {
        compare(DockItems.reorder(dock(), ["a", "b", "c"], 1, 5), ["b", "c", "a"]);
    }

    // Kept ids not on the dock are not lost.
    function test_reorder_keeps_what_is_not_shown() {
        compare(DockItems.reorder(dock(), ["gone", "a", "b", "c"], 1, 2), ["b", "a", "c", "gone"]);
    }

    function test_reorder_refuses() {
        compare(DockItems.reorder(dock(), ["a", "b", "c"], 1, 1), null);
        compare(DockItems.reorder(dock(), ["a", "b", "c"], 0, 2), null);
        compare(DockItems.reorder(dock(), ["a", "b", "c"], 6, 2), null);
        compare(DockItems.reorder(dock(), ["a", "b", "c"], 1, 7), null);
        compare(DockItems.reorder(undefined, [], 1, 2), null);
    }

    function test_when_it_hides() {
        verify(!DockItems.hidden("always", { windowNear: true }));
        verify(DockItems.hidden("autohide", {}));
        verify(!DockItems.hidden("autohide", { pointerInside: true }));
        verify(!DockItems.hidden("autohide", { menuOpen: true }));
        verify(DockItems.hidden("dodge", { windowNear: true }));
        verify(!DockItems.hidden("dodge", { windowNear: false }));
        verify(!DockItems.hidden("nonsense", { windowNear: true }));
    }

    // The strip at the edge: none for a dock that stays, a sliver while
    // hidden, the whole gap to the glass while shown.
    function test_edge_depth() {
        compare(DockItems.edgeDepth("always", false, 8), 0);
        compare(DockItems.edgeDepth("always", true, 8), 0);
        compare(DockItems.edgeDepth("nonsense", true, 8), 0);
        compare(DockItems.edgeDepth("autohide", true, 8), 3);
        compare(DockItems.edgeDepth("autohide", false, 8), 8);
        compare(DockItems.edgeDepth("dodge", true, 8), 3);
        compare(DockItems.edgeDepth("dodge", false, 8), 8);
        compare(DockItems.edgeDepth("autohide", false, 1), 3);
        compare(DockItems.edgeDepth("autohide", false, undefined), 3);
    }

    function test_rest_centres() {
        compare(DockItems.restCentres([48, 9, 48], 6), [24, 58.5, 93]);
        compare(DockItems.restCentres([], 6), []);
        compare(DockItems.restCentres(undefined, 6), []);
    }

    // The tile under the pointer grows most, its neighbours less, the far
    // ones not at all; on both sides alike.
    function test_magnify_falls_away() {
        const s = DockItems.magnify([0, 50, 100, 150, 200], 100, 2, 120);
        compare(s[2], 2);
        verify(s[1] > 1 && s[1] < 2);
        fuzzyCompare(s[1], s[3], 1e-9);
        verify(s[0] > 1 && s[0] < s[1]);
        compare(DockItems.magnify([0, 300], 0, 2, 120)[1], 1);
    }

    // Nowhere, or nothing to grow by: every tile as it is.
    function test_magnify_off() {
        compare(DockItems.magnify([0, 50], NaN, 2, 120), [1, 1]);
        compare(DockItems.magnify([0, 50], undefined, 2, 120), [1, 1]);
        compare(DockItems.magnify([0, 50], 0, 1, 120), [1, 1]);
        compare(DockItems.magnify([0, 50], 0, 0.5, 120), [1, 1]);
        compare(DockItems.magnify([0, 50], 0, 2, 0), [1, 1]);
        compare(DockItems.magnify(undefined, 0, 2, 120), []);
    }

    // A point inside a grown tile stretches with it; one in a gap or past
    // the end keeps its distance; nothing grown leaves every point put.
    function test_stretched() {
        const lens = [10, 10];
        compare(DockItems.stretched(lens, [2, 1], 2, 5), 10);
        compare(DockItems.stretched(lens, [2, 1], 2, 11), 21);
        compare(DockItems.stretched(lens, [2, 1], 2, 17), 27);
        compare(DockItems.stretched(lens, [2, 1], 2, 30), 40);
        compare(DockItems.stretched(lens, [2, 1], 2, -3), -3);
        for (const at of [0, 4, 10, 11, 15, 22, 40])
            compare(DockItems.stretched(lens, [1, 1], 2, at), at);
        compare(DockItems.stretched(lens, undefined, 2, 15), 15);
    }
}
