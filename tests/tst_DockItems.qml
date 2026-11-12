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

    function test_when_it_hides() {
        verify(!DockItems.hidden("always", { windowNear: true }));
        verify(DockItems.hidden("autohide", {}));
        verify(!DockItems.hidden("autohide", { pointerInside: true }));
        verify(!DockItems.hidden("autohide", { menuOpen: true }));
        verify(DockItems.hidden("dodge", { windowNear: true }));
        verify(!DockItems.hidden("dodge", { windowNear: false }));
        verify(!DockItems.hidden("nonsense", { windowNear: true }));
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
