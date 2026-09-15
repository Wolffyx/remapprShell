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
// appears, so it is never furniture with nothing behind it. The chevron sits
// after the icons, at the end of the tray, as the design has it -- or before
// them, which is where Plasma puts it and where it stays still while the
// icons beside it come and go.
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
import qs.core
import qs.domain.theme
import qs.domain.tray.layout
import qs.ui.primitives
import qs.ui.controls

BarWidget {
    id: root

    // The panel's tray icon size, unless this tray has one of its own.
    readonly property int configuredIconSize: root.widgetConfig?.iconSize ?? 0
    readonly property int size: root.configuredIconSize > 0 ? root.configuredIconSize : root.panelIconSize
    // Where the chevron sits along the tray. Everything below counts in
    // cells, so this is the one place the two arrangements differ: the cell
    // the chevron occupies, and therefore what each other cell holds.
    readonly property bool chevronFirst: (root.widgetConfig?.chevron ?? "after") === "before"

    readonly property var pinned: root.widgetConfig?.pinned ?? []
    readonly property var hidden: root.widgetConfig?.hidden ?? []

    // Each icon sits in a cell it lights up in, scaled with the panel.
    readonly property int cell: Math.max(root.size + 6, Math.round(38 * root.unit))
    readonly property int spacing: Math.max(2, Math.round(4 * root.unit))
    readonly property int stride: root.cell + root.spacing

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

    popoutPadding: root.popoutMode === "menu" ? 8 : 12

    // Which cell the pointer is over, or -1: an icon, or the chevron at
    // whichever end it sits. The panel reports a position along the widget;
    // turning that into an index is arithmetic rather than a handler per icon
    // -- the same approach the task buttons take.
    property int hoveredIndex: -1
    readonly property int chevronCell: root.chevronFirst ? 0 : root.shown.length
    readonly property bool overChevron: root.hasOverflow && root.hoveredIndex === root.chevronCell

    // Which cell an icon occupies, and which icon a cell holds -- the inverse
    // of each other, and the whole of what moving the chevron changes.
    function cellOf(index) {
        return root.chevronFirst && root.hasOverflow ? index + 1 : index;
    }

    // The icon under the pointer names itself, in the application's words.
    // A description may carry the markup the tray protocol allows; a tooltip
    // here is plain text, so tags are dropped rather than shown.
    tooltip: {
        if (root.overChevron)
            return `${root.overflow.length} hidden icon${root.overflow.length === 1 ? "" : "s"}`;
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
    tooltipCentre: root.hoveredIndex < 0 ? -1 : root.hoveredIndex * root.stride + root.cell / 2

    wantsHover: true
    // A right click opens the item's own menu, which is the whole of what a
    // tray icon offers.
    wantsRightClick: true
    wantsWheel: true

    implicitWidth: Math.max(root.cell, row.implicitWidth)
    implicitHeight: Math.max(root.cell, row.implicitHeight)

    // The chevron points away from the panel's edge, the way the flyout will
    // open, and back towards it while the flyout is open.
    readonly property string outward: ({ top: "expand_more", left: "chevron_right", right: "chevron_left" })[root.bar?.position] ?? "expand_less"
    readonly property string inward: ({ expand_less: "expand_more", expand_more: "expand_less",
                                        chevron_right: "chevron_left", chevron_left: "chevron_right" })[root.outward]

    function itemAt(cell) {
        if (cell < 0)
            return null;
        return root.shown[root.chevronFirst && root.hasOverflow ? cell - 1 : cell] ?? null;
    }

    function handleHover(position, horizontal) {
        const index = Math.floor(position / root.stride);
        const cells = root.shown.length + (root.hasOverflow ? 1 : 0);
        root.hoveredIndex = (position >= 0 && index >= 0 && index < cells) ? index : -1;
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
        if (root.overChevron) {
            root.showOverflow();
            return;
        }
        if (root.hoveredIndex < 0)
            return;
        root.act(root.itemAt(root.hoveredIndex), button, root.hoveredIndex * root.stride);
    }

    function showOverflow() {
        if (root.popoutVisible && root.popoutMode === "overflow") {
            root.closePopout();
            return;
        }
        root.menuItem = null;
        root.popoutMode = "overflow";
        root.popoutVisible = true;
        root.requestPopout("tray", root.chevronCell * root.stride + root.cell / 2);
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
            root.showMenu(item, offset + root.cell / 2);
            return;
        }

        if (button === Qt.MiddleButton) {
            item.secondaryActivate();
            return;
        }

        // Some items have no activate action at all and say so; for those a
        // left click is the menu, which is what the application intends.
        if (item.onlyMenu)
            root.showMenu(item, offset + root.cell / 2);
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

        // Drawn first when it comes first. A Grid lays its children out in
        // the order they are declared, and `visible: false` is skipped -- so
        // the two are one component used twice rather than a Repeater over a
        // list with a hole in it.
        Chevron { shown: root.hasOverflow && root.chevronFirst }

        Repeater {
            model: ScriptModel { values: root.shown }

            Item {
                id: entry

                required property SystemTrayItem modelData
                required property int index

                width: root.cell
                height: root.cell

                // The hover highlight is drawn from the panel's hover
                // position rather than a HoverHandler per icon: the panel
                // already tracks the pointer for the widget, and a second
                // tracker per icon would fight it.
                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(12 * Math.max(0.7, root.unit))
                    color: root.hoveredIndex === root.cellOf(entry.index) ? Theme.s2 : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                PanelIcon {
                    anchors.centerIn: parent
                    implicitSize: root.size
                    // The item's own icon wins; its id is the fallback so a
                    // badly-behaved application still shows something.
                    source: entry.modelData.icon
                    fallbackName: entry.modelData.id
                    opacity: entry.modelData.status === Status.Passive ? 0.5 : 1
                }
            }
        }

        Chevron { shown: root.hasOverflow && !root.chevronFirst }
    }

    // Shown only when something is behind it.
    component Chevron: Item {
        id: chevron

        required property bool shown

        visible: chevron.shown
        width: chevron.shown ? root.cell : 0
        height: root.cell

        Rectangle {
            anchors.fill: parent
            radius: Math.round(12 * Math.max(0.7, root.unit))
            color: root.popoutVisible && root.popoutMode === "overflow" || root.overChevron ? Theme.s2 : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Glyph {
            anchors.centerIn: parent
            name: root.popoutVisible && root.popoutMode === "overflow" ? root.inward : root.outward
            fallback: "arrow-up"
            size: root.size
            color: Theme.mut
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
                    title: root.menuItem ? (root.menuItem.tooltipTitle || root.menuItem.title || root.menuItem.id) : ""
                    iconSource: root.menuItem?.icon ?? ""
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
        Column {
            spacing: 10

            Grid {
                id: flyout

                // Four across, as the design has it, then more rows. Only
                // `columns` is set -- see ZoneRow.
                columns: Math.min(4, Math.max(1, root.overflow.length))
                spacing: 6

                Repeater {
                    model: ScriptModel { values: root.overflow }

                    Item {
                        id: hiddenEntry

                        required property SystemTrayItem modelData

                        implicitWidth: 38
                        implicitHeight: 38

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusOf(12)
                            color: hiddenHover.hovered ? Theme.s2 : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        }

                        PanelIcon {
                            anchors.centerIn: parent
                            implicitSize: root.size
                            source: hiddenEntry.modelData.icon
                            fallbackName: hiddenEntry.modelData.id
                            opacity: hiddenEntry.modelData.status === Status.Passive ? 0.5 : 1
                        }

                        HoverHandler { id: hiddenHover; cursorShape: Qt.PointingHandCursor }

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

            Rectangle {
                width: Math.max(flyout.width, manage.implicitWidth)
                height: 1
                color: Theme.out
            }

            // Which icons sit where is the settings window's to change, where
            // each can be dragged between the three lists.
            TextButton {
                id: manage
                anchors.horizontalCenter: parent.horizontalCenter
                glyph: "apps"
                iconName: "configure"
                text: "Manage tray icons"
                onActivated: {
                    Quickshell.execDetached([Branding.ctlBin, "settings", "tray"]);
                    root.closePopout();
                }
            }
        }
    }
}
