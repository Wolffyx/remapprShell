pragma ComponentBehavior: Bound

// The open windows, and the applications kept on the taskbar.
//
// Icons only. A panel is the one surface with no room to spare, and a row of
// titles runs out of it after four or five windows -- which is why every
// desktop that ships a task manager defaults to icons and puts the title in a
// preview. The title is one hover away.
//
// Clicks and hovers come through the panel rather than from handlers of our
// own: a widget that declares `wantsHover` gets the position along itself and
// the button that was pressed, which is the whole interface. Doing it here
// with a TapHandler per button also cost a click, because the panel takes the
// keyboard when clicked and the window that had just been activated lost it
// again.
//
// The buttons do what Windows' do. A click activates, and on the window that
// is already active it minimises; on an application with several windows it
// moves through them. A middle click starts another instance. A right click
// opens a menu (TaskMenu): the application's own actions, pinning, closing.
// Pinned applications stay on the taskbar, first and in the order pinned,
// whether or not they are running. KWin does everything asked of it; nothing
// here moves or rearranges a window.
//
// This file is the row's state and what the panel's clicks and hovers do to
// it. A button is drawn by TaskButton, and the popout -- the menu, or the
// preview (TaskPreview) -- is TaskPopout.

import QtQuick
import Quickshell
import qs.domain.desktops
import qs.domain.windows
import qs.domain.windows.events
import qs.ui.primitives

BarWidget {
    id: root

    readonly property bool showTitles: root.widgetConfig?.showTitles ?? false
    readonly property int maxWidth: root.widgetConfig?.maxWidth ?? 180

    // Follows the panel unless a size was chosen. Everything here is derived
    // from `bar.thickness`, so making the panel thicker or thinner resizes the
    // buttons and their icons with it rather than leaving a row of small icons
    // in a tall strip.
    readonly property int configuredIconSize: root.widgetConfig?.iconSize ?? 0

    // How much of the button the icon fills, as a percentage. It used to be a
    // size worked out from the panel's thickness alone -- 28 units against a
    // 48-unit button -- which left an icon of 23px in a 39px button on a 52px
    // panel: under half the panel's height was the icon, and the rest read as
    // padding nobody asked for.
    readonly property int iconScale: root.widgetConfig?.iconScale ?? 72
    readonly property int iconSize: root.configuredIconSize > 0
        ? root.configuredIconSize
        : Math.max(16, Math.min(56, Math.round(root.buttonHeight * root.iconScale / 100)))

    readonly property bool groupByApp: root.widgetConfig?.groupByApp ?? true

    // The application's name above its preview cards, and a second square
    // peeking out behind the icon of an application with several windows.
    readonly property bool previewHeader: root.widgetConfig?.previewHeader ?? false
    readonly property bool previewScreen: root.widgetConfig?.previewScreen ?? false
    readonly property bool stackGroups: root.widgetConfig?.stackGroups ?? true

    // Desktop entry ids, in the order they sit on the taskbar.
    readonly property var pinned: root.widgetConfig?.pinned ?? []

    // Only the windows on this panel's own monitor, when asked -- Windows'
    // "show taskbar apps on the taskbar where the window is open". A window
    // with no monitor named (a script older than that field) is shown
    // everywhere rather than nowhere.
    readonly property bool thisScreenOnly: root.widgetConfig?.thisScreenOnly ?? false

    // And only the windows on the desktop in front, which is what KDE's own
    // task manager and Windows both do by default. A window on every desktop
    // -- an empty list, in KWin's terms -- is on this one too.
    readonly property bool thisDesktopOnly: root.widgetConfig?.thisDesktopOnly ?? true

    function onThisDesktop(window) {
        if (!root.thisDesktopOnly)
            return true;
        const on = window?.desktops ?? [];
        return on.length === 0 || on.indexOf(Desktops.currentId) >= 0;
    }

    readonly property var windowsHere: (root.thisScreenOnly
        ? WindowsService.windows.filter(w => !w.output || w.output === root.screenName)
        : WindowsService.windows).filter(w => root.onThisDesktop(w))

    // One item per application when grouping, one per window otherwise. Both
    // are the same shape -- a list of {windows, appName, icon...} -- so the row
    // below does not care which it is drawing.
    readonly property var running: root.groupByApp
        ? WindowsService.groupsOf(root.windowsHere)
        : root.windowsHere.map(w => ({
            key: w.uuid,
            appKey: String(WindowsService.entryFor(w)?.id ?? ""),
            appName: WindowsService.appNameFor(w),
            windows: [w],
            active: w.active === true,
            attention: (WindowsService.attentionSince[w.uuid] ?? 0) > 0,
            attentionSince: WindowsService.attentionSince[w.uuid] ?? 0,
            iconName: WindowsService.iconFor(w),
            iconFile: WindowsService.iconFileFor(w)
        }))

    // Pinned first, then the rest: see WindowEvents.arrangeTasks.
    readonly property var items: WindowEvents.arrangeTasks(root.running, root.pinned,
                                                           id => WindowsService.launcherFor(id))

    // A button's item: the one at its place, which is where it is once the
    // list has settled, as long as the key agrees -- and found by key while
    // the list is still moving under it. The buttons are repeated over the
    // keys (see below), so this is how each reads what it shows.
    function itemFor(index, key) {
        const at = root.items[index];
        return at?.key === key ? at : (root.items.find(i => i.key === key) ?? root.noItem);
    }

    // What a button on its way out reads, for the moment between its key
    // leaving the list and the button going.
    readonly property var noItem: ({ key: "", appName: "", windows: [], active: false, attention: false,
                                     attentionSince: 0, iconName: "", iconFile: "" })

    // As tall as the design's buttons at this thickness. With titles a
    // button is as wide as its title needs, up to `maxWidth`; without, it is
    // the icon and its padding.
    readonly property int buttonHeight: Math.max(22, Math.round(48 * root.unit))
    readonly property int padding: Math.round((root.showTitles ? 16 : 12) * Math.max(0.7, root.unit))
    readonly property int spacing: Math.max(2, Math.round(6 * root.unit))

    // When the row would not fit the room the panel has for it, every
    // button is cut to an equal share of it -- titles elided first, then gone
    // below a readable width, down to the icon alone.
    readonly property real iconOnly: root.iconSize + 2 * root.padding
    givesWay: true
    readonly property real share: Math.max(root.iconOnly, root.wanted)

    // Past a certain number of windows even the icon alone does not fit, and a
    // Row does not shrink: the buttons kept their width and ran on past the
    // end of the zone, over the widgets beside them. Reported as the icons
    // sitting one on top of another.
    //
    // So below that point they are squeezed -- the padding first, since it is
    // the emptiest pixels, and the icon after it, down to a floor where an
    // icon is still an icon. Below even that the row is clipped: something has
    // to give, and it should be the last button rather than the clock.
    readonly property real wanted: root.room >= 0 && root.items.length > 0
        ? (root.room - root.spacing * (root.items.length - 1)) / root.items.length
        : 1e9
    readonly property real squeeze: root.wanted >= root.iconOnly
        ? 1
        : Math.max(0.5, root.wanted / root.iconOnly)
    readonly property int drawnIcon: Math.max(12, Math.round(root.iconSize * root.squeeze))
    readonly property int drawnPadding: root.squeeze === 1
        ? root.padding
        : Math.max(2, Math.round(root.padding * root.squeeze * 0.6))
    readonly property real drawnIconOnly: root.drawnIcon + 2 * root.drawnPadding
    readonly property real titleRoom: Math.min(root.maxWidth, root.share) - root.iconOnly - Math.round(10 * Math.max(0.7, root.unit))
    readonly property bool titlesFit: root.showTitles && root.titleRoom >= 28

    // Buttons differ in width once they carry titles, so the one under the
    // pointer is found by where each actually is (BarWidget.indexAlong)
    // rather than by dividing the position by one width. The taskbar runs
    // along the panel only.
    function indexAt(position) {
        return root.indexAlong(buttons, position, root.spacing, false);
    }

    function centreOf(index) {
        return Math.max(0, root.centreAlong(buttons, index, false));
    }

    // The preview's cards carry their own inner margin, so the card around
    // them adds only a little: 14 on top of theirs was the wide empty border
    // round a single window.
    popoutPadding: root.popoutMode === "menu" ? 8 : 6
    // The menu is a list of actions and has a width of its own; the preview
    // is a picture and takes its size from what it is showing.
    readonly property int menuWidth: 262
    popoutWidth: root.popoutMode === "menu" ? root.menuWidth : -1

    // The preview is reached across an invisible bridge from its button:
    // the gap above the row was the one stretch of the way to the card that
    // was not the card, and the card started closing while the pointer
    // crossed it. The bridge is exactly as wide as the button the preview is
    // about -- its icon and its margin -- and nothing of it is drawn
    // (BarWidget.popoutTail). The menu is a menu, and stands clear as the
    // others do.
    popoutTail: root.popoutMode !== "menu"
    popoutTailWidth: buttons.itemAt(root.items.findIndex(i => i.key === root.previewKey))?.width ?? root.drawnIconOnly

    // Which button the pointer is over, or -1. The panel reports the position
    // along the widget; turning that into an index is arithmetic rather than a
    // handler per button.
    property int hoveredIndex: -1

    // Which button the preview is *about*, which is not the same question.
    // Reaching the card means taking the pointer off the button, so a card
    // that read `hoveredIndex` emptied itself on the way there and could never
    // be clicked -- which is exactly what "the popup disappears" was.
    //
    // Kept as the button's key, and its item looked up afresh from `items`.
    // The card used to hold the item itself, which was a snapshot: a window
    // closed from the card stayed on it, and the first movement of the
    // pointer after any change to the window list handed it a new object,
    // which rebuilt every card and restarted every live picture. Still
    // writable: dev/preview/popout.qml points the card at a group by setting
    // it.
    property string previewKey: ""
    property var previewItem: root.items.find(i => i.key === root.previewKey) ?? null

    // Its last window closed -- from the card or anywhere else -- the card
    // goes with it, rather than staying up empty. For most applications the
    // group goes too; a pinned one stays on the taskbar with no windows, and
    // its card turned into "Pinned -- click to start it" under the pointer
    // that had just closed it (2026-09-24). A card that opened on a pinned
    // application with nothing running is a different thing, and stays.
    // Asked of `items` rather than of `previewItem`: clearing the key from
    // inside that property's own change is a binding loop.
    property int _previewWindows: 0

    onPreviewKeyChanged: root._previewWindows = root.items.find(i => i.key === root.previewKey)?.windows.length ?? 0

    onItemsChanged: {
        if (root.previewKey.length === 0 || root.popoutMode === "menu")
            return;
        const shown = root.items.find(i => i.key === root.previewKey)?.windows.length ?? -1;
        if (shown < 0 || (shown === 0 && root._previewWindows > 0)) {
            root.previewKey = "";
            root.popoutVisible = false;
            return;
        }
        root._previewWindows = shown;
    }

    // And the card stays up while the pointer crosses the gap to it. Leaving
    // the button starts a short countdown rather than closing; entering the
    // card stops it. Windows and Plasma both do this, and without it a hover
    // preview can only ever be looked at.
    //
    // "The card" is the panel's word for it (popoutHovered): the whole card
    // and the neck it hangs by. The preview's own contents stop short of the
    // card's padding and know nothing of the neck, so watching them started
    // the countdown on the very way to the card.
    property bool pointerInPopout: false

    onPopoutHoveredChanged: {
        root.pointerInPopout = root.popoutHovered;
        if (root.popoutHovered)
            root.cancelClose();
        else if (root.popoutVisible)
            root.beginClose();
    }

    readonly property Timer _closeDelay: Timer {
        interval: 280
        onTriggered: {
            if (root.popoutMode === "menu" || root.pointerInPopout || root.hoveredIndex >= 0)
                return;
            root.popoutVisible = false;
            root.previewKey = "";
        }
    }

    function beginClose() {
        if (root.popoutMode !== "menu")
            root._closeDelay.restart();
    }

    function cancelClose() {
        root._closeDelay.stop();
    }

    // What the popout shows: the preview while the pointer is over a button,
    // or a button's menu after a right click. The menu stays put while the
    // pointer travels to it, and a click anywhere else closes it; the preview
    // follows the pointer and closes by itself.
    property string popoutMode: "preview"
    property var menuItem: null

    wantsHover: true
    // A right click opens the button's menu (TaskMenu), so the panel's own
    // menu stays out of the way here.
    wantsRightClick: true
    popoutClosesOnOutsideClick: root.popoutMode === "menu"

    // How long a button flashes once its window asks for attention, before
    // settling to a steady tint.
    readonly property int flashMs: 6000

    implicitWidth: root.room >= 0 ? Math.min(row.implicitWidth, root.room) : row.implicitWidth
    implicitHeight: root.barThickness

    function handleHover(position, horizontal) {
        root.hoveredIndex = root.indexAt(position);

        if (root.popoutMode === "menu")
            return;
        if (root.hoveredIndex >= 0) {
            root.cancelClose();
            root.previewKey = root.items[root.hoveredIndex]?.key ?? "";
            root.popoutVisible = true;
            root.requestPopout("tasks", root.centreOf(root.hoveredIndex));
        } else {
            // Between two buttons, still on the widget. The card goes, but not
            // instantly: crossing a 5px gap should not cost the card.
            root.beginClose();
        }
    }

    // `dismissPopout` is a signal on the base type -- the panel emits it when
    // the pointer leaves -- so this handles it rather than defining a function
    // of the same name, which is a silent clash at load time. The pointer
    // leaving is how it reaches an open menu, so the menu stays.
    onDismissPopout: {
        root.hoveredIndex = -1;
        root.beginClose();
    }

    // However it closed -- chosen from, clicked away from, replaced by another
    // popout -- the next one opens as the preview again.
    onPopoutVisibleChanged: {
        if (!root.popoutVisible) {
            root.popoutMode = "preview";
            root.menuItem = null;
            root.previewKey = "";
            root.pointerInPopout = false;
            root.cancelClose();
        }
    }

    function handleActivate(button) {
        const item = root.items[root.hoveredIndex] ?? null;

        // A click on the taskbar while the menu is open closes it and does
        // nothing else -- unless it is another right click, which moves the
        // menu to that button.
        if (root.popoutMode === "menu") {
            root.popoutVisible = false;
            if (button !== Qt.RightButton)
                return;
        }
        if (!item)
            return;

        if (button === Qt.RightButton) {
            root.openMenu(item);
            return;
        }
        if (button === Qt.MiddleButton || item.windows.length === 0) {
            WindowsService.launch(WindowEvents.appIdOf(item), null);
            return;
        }
        // The active window's own button minimises it, as on Windows.
        if (item.windows.length === 1 && item.windows[0].active) {
            WindowsService.minimizeActive();
            return;
        }
        WindowsService.activateGroup(item);
    }

    function openMenu(item) {
        root.menuItem = item;
        root.popoutMode = "menu";
        root.popoutVisible = true;
        root.requestPopout("tasks", root.centreOf(root.items.indexOf(item)));
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing
        // The last line of defence: with the buttons already at their floor
        // the row is still wider than the zone, and what is left over is cut
        // rather than drawn over the neighbours.
        clip: true
        width: root.room >= 0 ? Math.min(row.implicitWidth, root.room) : row.implicitWidth

        Repeater {
            id: buttons

            // Over the keys, not the items. `items` is made afresh on every
            // push from the window daemon -- any window's title changing is
            // one -- and a Repeater over it built every button again each
            // time, each with its timer and its animation. Over the keys a
            // button lives as long as its application or window is on the
            // list, and reads its item through itemFor.
            model: ScriptModel { values: root.items.map(i => i.key) }

            TaskButton { taskbar: root }
        }
    }

    // One popout, two contents: a button's menu, or the preview. What each
    // is and does is TaskPopout's.
    popout: Component {
        TaskPopout { taskbar: root }
    }
}
