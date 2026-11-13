// The dock, offscreen: the tiles along the bottom with the name over one,
// and the menu open over another -- with a made-up set of applications.
// Also the "Copied" toast from the clipboard, at a pointer.
//
//   dev/preview/preview.sh dev/preview/dock.qml out.png 1280 720 dark
//
// PREVIEW_DOCK=left|right puts the dock on a side. PREVIEW_MAGNIFY=1 draws it
// magnified round Firefox, with its name over it, and no menu.
// PREVIEW_DRAG=1 holds Dolphin as if dragged two tiles on: the two it has
// passed step back to open its place.

import QtQuick
import Quickshell
import qs.domain.dock
import qs.domain.surfaces
import qs.domain.theme
import qs.features.dock
import qs.features.overlays

Rectangle {
    id: stage
    color: Theme.dark ? "#0c0e15" : "#d8dae1"

    readonly property string side: Quickshell.env("PREVIEW_DOCK") || "bottom"
    readonly property bool magnified: Quickshell.env("PREVIEW_MAGNIFY") === "1"
    readonly property bool dragged: Quickshell.env("PREVIEW_DRAG") === "1"

    // What Dock.qml is, without the layer surface: the numbers and the
    // answers the body and the menu ask it for.
    QtObject {
        id: fake

        readonly property string position: stage.side
        readonly property bool horizontal: stage.side === "bottom"
        readonly property int size: 48
        readonly property int pad: Math.round(fake.size * 0.19)
        readonly property int gap: Math.round(fake.size * 0.125)
        readonly property int margin: 8
        readonly property int thickness: fake.size + 2 * fake.pad
        readonly property real width: stage.width
        readonly property real height: stage.height
        readonly property bool hidden: false
        readonly property int dividerLength: 9
        property var menuItem: null

        readonly property var items: DockItems.items([
            { key: "org.kde.dolphin", appKey: "org.kde.dolphin", appName: "Dolphin", iconName: "system-file-manager",
              windows: [{ uuid: "a", active: true }], active: true },
            { key: "org.kde.konsole", appKey: "org.kde.konsole", appName: "Konsole", iconName: "utilities-terminal",
              windows: [{ uuid: "b" }, { uuid: "c" }] },
            { key: "firefox", appKey: "firefox", appName: "Firefox", iconName: "firefox", windows: [] },
            { key: "org.kde.kate", appKey: "org.kde.kate", appName: "Kate", iconName: "kate", windows: [] },
            { key: "class:steam", appKey: "", appName: "Steam", iconName: "steam", windows: [{ uuid: "d" }],
              attention: true }
        ], { pinned: ["org.kde.dolphin", "firefox", "org.kde.kate"], places: true, downloads: "/home/u/Downloads" })

        // Magnified round Firefox's tile, at twice its size.
        readonly property var lengths: fake.items.map(i => i.kind === "divider" ? fake.dividerLength : fake.size)
        readonly property var scales: stage.magnified
            ? DockItems.magnify(DockItems.restCentres(fake.lengths, fake.gap), DockItems.restCentres(fake.lengths, fake.gap)[3] + 10,
                                2, 2.5 * (fake.size + fake.gap))
            : []
        readonly property int lift: stage.magnified ? fake.size : 0

        function activate(item, button) {}
        // Konsole's entry, with actions of its own as Konsole declares them.
        function entryOf(item) {
            return item?.appKey === "org.kde.konsole"
                ? { actions: [{ name: "Open a new window", icon: "window-new" },
                              { name: "Open a new tab", icon: "tab-new" }] }
                : null;
        }
        function launchAction(item, action) {}
        function isPinned(item) { return ["org.kde.dolphin", "firefox"].indexOf(item?.appKey) >= 0; }
        function togglePin(item) {}
        function closeWindows(item) {}
    }

    DockBody {
        id: body
        dock: fake
        x: fake.horizontal ? (stage.width - width) / 2 : (stage.side === "left" ? fake.margin : stage.width - fake.margin - width)
        y: fake.horizontal ? stage.height - fake.margin - height : (stage.height - height) / 2
        Component.onCompleted: {
            if (stage.dragged) {
                body.reorder.begin(1);
                body.reorder.track(1, 2 * (fake.size + fake.gap));
                return;
            }
            if (stage.magnified) {
                const grid = body.children[0];
                body.hover(grid.children.find(c => c.modelData === fake.items[3].key), fake.items[3]);
                return;
            }
            body.hoveredItem = fake.items[2];
            body.hoveredCentre = fake.horizontal ? body.x + 200 : body.y + 200;
        }
    }

    DockMenu {
        dock: fake
        body: body
        Component.onCompleted: fake.menuItem = stage.magnified || stage.dragged ? null : fake.items[2]
    }

    // The toast, as it is drawn at a pointer.
    CopiedToast {
        width: stage.width
        height: stage.height
        Component.onCompleted: Surfaces.showCopied({ label: "rmpr reload", screen: "", x: 80, y: 60 })
    }
}
