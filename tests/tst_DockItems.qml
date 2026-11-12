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
}
