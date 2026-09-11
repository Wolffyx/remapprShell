pragma ComponentBehavior: Bound

// System tray.
//
// Quickshell runs the StatusNotifierHost, so this works on KWin with no
// KDE-specific code. Nothing here touches org.kde.StatusNotifierWatcher.
//
// Three states, which is what a tray needs and what Windows and Plasma both
// settle on:
//
//   pinned   on the panel, in the order given
//   overflow behind the chevron, one click away
//   hidden   not shown at all
//
// `pinned` empty means "everything on the panel", so a fresh install shows the
// tray it has rather than an empty strip and a chevron. Pin anything and the
// rest move behind the chevron -- which is the moment the chevron first
// appears, so it is never furniture with nothing behind it.
//
// Every interaction an application expects is here. A tray icon whose menu
// does not open is a broken tray icon, and `secondaryActivate` on right-click
// -- what this used to do -- is not the menu: it is a different action
// entirely, which most applications either ignore or use for something else.
//
// The widget has one popout and two things to put in it: the overflow flyout
// and an item's menu. It switches rather than opening a second window, which
// keeps all the placement, sizing and edge-clamping in the panel where it
// already works.

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.domain.theme
import qs.domain.tray.layout
import qs.ui.primitives

BarWidget {
    id: root

    readonly property int iconSize: root.widgetConfig?.iconSize ?? 18
    readonly property var pinned: root.widgetConfig?.pinned ?? []
    readonly property var hidden: root.widgetConfig?.hidden ?? []
    readonly property int spacing: 6

    // The rules live in TrayLayout, which the settings page reads too -- so
    // the page cannot show one arrangement while the panel draws another.
    readonly property var arrangement: TrayLayout.split(SystemTray.items?.values ?? [],
                                                        root.pinned, root.hidden)
    readonly property var shown: root.arrangement.shown
    readonly property var overflow: root.arrangement.overflow

    readonly property bool hasOverflow: root.overflow.length > 0

    // What the popout is showing. One popout, two contents.
    property string popoutMode: "overflow"
    property var menuItem: null

    // Which icon the pointer is over, or -1. The panel reports a position
    // along the widget; turning that into an index is arithmetic rather than a
    // handler per icon -- the same approach the task buttons take.
    property int hoveredIndex: -1

    // The icon under the pointer names itself, in the application's words.
    // A description may carry the markup the tray protocol allows; a tooltip
    // here is plain text, so tags are dropped rather than shown.
    tooltip: {
        const item = root.itemAt(root.hoveredIndex);
        if (!item)
            return "";
        const title = item.tooltipTitle || item.title || item.id;
        const detail = (item.tooltipDescription ?? "")
            .replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&")
            .trim();
        return detail && detail !== title ? `${title}\n${detail}` : title;
    }
    tooltipCentre: root.hoveredIndex < 0 ? -1
        : root.leading + root.hoveredIndex * (root.iconSize + root.spacing) + root.iconSize / 2

    // The chevron sits first, as it does on Windows, so the icons do not move
    // sideways when one is pinned or unpinned.
    readonly property int leading: root.hasOverflow ? root.iconSize + root.spacing : 0

    wantsHover: true
    wantsWheel: true

    implicitWidth: Math.max(root.iconSize, row.implicitWidth)
    implicitHeight: Math.max(root.iconSize, row.implicitHeight)

    // The chevron points away from the panel's edge, the way the flyout will
    // open, and back towards it while the flyout is open.
    readonly property string outward: ({ top: "down", left: "right", right: "left" })[root.bar?.position] ?? "up"
    readonly property string inward: ({ up: "down", down: "up", left: "right", right: "left" })[root.outward]

    function itemAt(index) {
        return root.shown[index] ?? null;
    }

    function handleHover(position, horizontal) {
        const stride = root.iconSize + root.spacing;
        const index = Math.floor((position - root.leading) / stride);
        root.hoveredIndex = (position >= root.leading && index >= 0 && index < root.shown.length)
            ? index : -1;
    }

    // The flyout stays open until the chevron is clicked again, so leaving the
    // widget must not close it -- the pointer has to leave to reach it. Hover
    // is still wanted, for the icon under the pointer.
    onDismissPopout: root.hoveredIndex = -1

    function handleWheel(delta) {
        const item = root.itemAt(root.hoveredIndex);
        if (item)
            item.scroll(Math.round(delta * 120), false);
    }

    function handleActivate(button) {
        if (root.hoveredIndex < 0) {
            // The chevron, or the gap beside it.
            if (root.hasOverflow)
                root.showOverflow();
            return;
        }
        root.act(root.itemAt(root.hoveredIndex), button,
                 root.leading + root.hoveredIndex * (root.iconSize + root.spacing));
    }

    function showOverflow() {
        if (root.popoutVisible && root.popoutMode === "overflow") {
            root.closePopout();
            return;
        }
        root.menuItem = null;
        root.popoutMode = "overflow";
        root.popoutVisible = true;
        root.requestPopout("tray", root.iconSize / 2);
    }

    function showMenu(item, centre) {
        if (!item?.hasMenu)
            return;
        // Reopening on the same item closes it, the way a menu behaves.
        if (root.popoutVisible && root.popoutMode === "menu" && root.menuItem === item) {
            root.closePopout();
            return;
        }
        root.menuItem = item;
        root.popoutMode = "menu";
        root.popoutVisible = true;
        root.requestPopout("tray", centre);
    }

    function closePopout() {
        root.popoutVisible = false;
        root.menuItem = null;
        root.popoutMode = "overflow";
    }

    // What a click does, in one place, so an icon behaves the same on the
    // panel and in the flyout.
    //
    // The menu is drawn by TrayMenu rather than handed to Qt: see the note at
    // the top of that file for why `display()` cannot be used over layer-shell.
    function act(item, button, offset) {
        if (!item)
            return;

        if (button === Qt.RightButton) {
            root.showMenu(item, offset + root.iconSize / 2);
            return;
        }

        if (button === Qt.MiddleButton) {
            item.secondaryActivate();
            return;
        }

        // Some items have no activate action at all and say so; for those a
        // left click is the menu, which is what the application intends.
        if (item.onlyMenu)
            root.showMenu(item, offset + root.iconSize / 2);
        else
            item.activate();

        if (root.popoutVisible && root.popoutMode === "menu")
            root.closePopout();
    }

    // One line along the panel, whichever way the panel runs -- a Row here
    // cut the tray to two icons on a panel down the side of the screen. Only
    // `columns` is set, from the cells actually shown; see ZoneRow for why
    // setting both, or counting hidden cells, goes wrong. The hover arithmetic
    // above works along either axis unchanged, because the panel reports the
    // position along its own length.
    Grid {
        id: row
        anchors.centerIn: parent
        spacing: root.spacing
        columns: (root.bar?.horizontal ?? true)
            ? Math.max(1, root.shown.length + (root.hasOverflow ? 1 : 0))
            : 1
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        // Shown only when something is behind it.
        Item {
            visible: root.hasOverflow
            width: root.hasOverflow ? root.iconSize : 0
            height: root.iconSize

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: root.popoutVisible ? PlasmaColors.hoverBackground : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            PanelIcon {
                anchors.centerIn: parent
                implicitSize: Math.round(root.iconSize * 0.8)
                iconName: `arrow-${root.popoutVisible ? root.inward : root.outward}`
            }
        }

        Repeater {
            model: ScriptModel { values: root.shown }

            Item {
                id: entry

                required property SystemTrayItem modelData
                required property int index

                width: root.iconSize
                height: root.iconSize

                // The hover highlight is drawn from the panel's hover
                // position rather than a HoverHandler per icon: the panel
                // already tracks the pointer for the widget, and a second
                // tracker per icon would fight it.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: 4
                    color: root.hoveredIndex === entry.index
                        ? PlasmaColors.hoverBackground : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                PanelIcon {
                    anchors.fill: parent
                    // The item's own icon wins; its id is the fallback so a
                    // badly-behaved application still shows something.
                    source: entry.modelData.icon
                    fallbackName: entry.modelData.id
                    opacity: entry.modelData.status === Status.Passive ? 0.5 : 1
                }
            }
        }
    }

    // One popout, two contents: an item's menu, or the flyout of what is
    // behind the chevron.
    popout: Component {
        Item {
            // The loaded contents are Items; the linter only knows they are
            // QObjects, so they are read through a typed alias.
            readonly property Item shownContent: (menuLoader.item ?? flyoutLoader.item) as Item

            implicitWidth: Math.max(shownContent?.implicitWidth ?? 0, 40)
            implicitHeight: Math.max(shownContent?.implicitHeight ?? 0, 20)

            Loader {
                id: menuLoader
                active: root.popoutMode === "menu" && root.menuItem !== null
                sourceComponent: TrayMenu {
                    handle: root.menuItem?.menu ?? null
                    onChosen: root.closePopout()
                }
            }

            Loader {
                id: flyoutLoader
                active: root.popoutMode === "overflow"
                sourceComponent: root.overflowGrid
            }
        }
    }

    readonly property Component overflowGrid: Component {
        Grid {
            id: flyout

            readonly property int columns_: Math.min(6, Math.max(1, root.overflow.length))

            columns: flyout.columns_
            rows: -1
            spacing: 8

            Repeater {
                model: ScriptModel { values: root.overflow }

                Item {
                    id: hiddenEntry

                    required property SystemTrayItem modelData

                    implicitWidth: root.iconSize + 12
                    implicitHeight: root.iconSize + 12

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        color: hiddenHover.hovered ? PlasmaColors.hoverBackground : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    PanelIcon {
                        anchors.centerIn: parent
                        implicitSize: root.iconSize
                        source: hiddenEntry.modelData.icon
                        fallbackName: hiddenEntry.modelData.id
                        opacity: hiddenEntry.modelData.status === Status.Passive ? 0.5 : 1
                    }

                    HoverHandler { id: hiddenHover }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: event => root.act(hiddenEntry.modelData, event.button, 0)
                        onWheel: event => {
                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y
                                                                   : event.pixelDelta.y * 2.4;
                            hiddenEntry.modelData.scroll(Math.round(delta), false);
                        }
                    }
                }
            }
        }
    }
}
