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

import QtQuick
import qs.domain.config
import qs.domain.desktops
import qs.domain.theme
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
    readonly property real share: root.room >= 0 && root.items.length > 0
        ? Math.max(root.iconOnly, (root.room - root.spacing * (root.items.length - 1)) / root.items.length)
        : 1e9

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
    // pointer is found by where each actually is rather than by dividing the
    // position by one width.
    function indexAt(position) {
        for (let i = 0; i < buttons.count; i++) {
            const b = buttons.itemAt(i);
            if (b && position >= b.x - root.spacing / 2 && position < b.x + b.width + root.spacing / 2)
                return i;
        }
        return -1;
    }

    function centreOf(index) {
        const b = buttons.itemAt(index);
        return b ? b.x + b.width / 2 : 0;
    }

    popoutPadding: root.popoutMode === "menu" ? 8 : 14
    // The menu is a list of actions and has a width of its own; the preview
    // is a picture and takes its size from what it is showing.
    readonly property int menuWidth: 262
    popoutWidth: root.popoutMode === "menu" ? root.menuWidth : -1

    // Which button the pointer is over, or -1. The panel reports the position
    // along the widget; turning that into an index is arithmetic rather than a
    // handler per button.
    property int hoveredIndex: -1

    // Which button the preview is *about*, which is not the same question.
    // Reaching the card means taking the pointer off the button, so a card
    // that read `hoveredIndex` emptied itself on the way there and could never
    // be clicked -- which is exactly what "the popup disappears" was.
    property var previewItem: null

    // And the card stays up while the pointer crosses the gap to it. Leaving
    // the button starts a short countdown rather than closing; entering the
    // card stops it. Windows and Plasma both do this, and without it a hover
    // preview can only ever be looked at.
    property bool pointerInPopout: false

    readonly property Timer _closeDelay: Timer {
        interval: 280
        onTriggered: {
            if (root.popoutMode === "menu" || root.pointerInPopout || root.hoveredIndex >= 0)
                return;
            root.popoutVisible = false;
            root.previewItem = null;
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
    implicitHeight: root.bar.thickness

    function handleHover(position, horizontal) {
        root.hoveredIndex = root.indexAt(position);

        if (root.popoutMode === "menu")
            return;
        if (root.hoveredIndex >= 0) {
            root.cancelClose();
            root.previewItem = root.items[root.hoveredIndex];
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
            root.previewItem = null;
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
            model: root.items

            Rectangle {
                id: button

                required property var modelData
                required property int index

                readonly property bool isActive: button.modelData.active === true
                // A group is dimmed only when every window in it is minimised:
                // one visible window means the application is on screen. A
                // pinned application with no windows is not minimised, just
                // not running.
                readonly property bool isMinimized: button.windowCount > 0
                                                    && button.modelData.windows.every(w => w.minimized)
                readonly property bool isHovered: button.index === root.hoveredIndex
                readonly property int windowCount: button.modelData.windows.length

                width: root.titlesFit ? Math.min(root.maxWidth, root.share, content.implicitWidth + 2 * root.padding)
                                      : root.drawnIconOnly
                height: root.buttonHeight
                radius: Math.round(14 * Math.max(0.7, root.unit))

                // Buttons sit on the panel itself, as the design draws them:
                // no tile until hovered, and the focused window's in the
                // accent's container colour.
                color: button.isActive  ? Theme.accC
                     : button.isHovered ? Theme.s2
                                        : "transparent"

                // A minimised window is still there and still clickable; it is
                // dimmed rather than hidden, which is the whole difference
                // between a task list and a window list.
                opacity: button.isMinimized ? 0.55 : 1

                Behavior on color { ColorAnimation { duration: 100 } }

                // A window asking for attention -- a message arrived, a
                // dialog wants an answer -- flashes its button for a few
                // seconds and then keeps an orange tint until it is looked
                // at, as Windows does. KWin clears the request when the window
                // is activated, and the tint goes with it.
                //
                // The moment the request began is kept by WindowsService, not
                // here: any change to the window list rebuilds every button,
                // and a flash timed from the button would start over each
                // time some other window changed its title.
                readonly property bool wantsAttention: button.modelData.attention === true && !button.isActive
                property bool flashing: false

                function startFlash() {
                    const left = root.flashMs - (Date.now() - (button.modelData.attentionSince ?? 0));
                    button.flashing = button.wantsAttention && left > 0;
                    if (button.flashing) {
                        flashStop.interval = left;
                        flashStop.restart();
                    }
                }

                onWantsAttentionChanged: button.startFlash()
                Component.onCompleted: button.startFlash()

                Timer {
                    id: flashStop
                    onTriggered: button.flashing = false
                }

                Rectangle {
                    id: attentionTint
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.neutral
                    visible: button.wantsAttention
                    opacity: 0.45

                    SequentialAnimation on opacity {
                        running: button.flashing
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.9; duration: 420; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 0.15; duration: 420; easing.type: Easing.InOutQuad }
                    }
                }

                onFlashingChanged: if (!button.flashing) attentionTint.opacity = 0.45

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: Math.round(10 * Math.max(0.7, root.unit))

                    PanelIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: root.drawnIcon
                        iconName: button.modelData.iconName
                        iconFile: button.modelData.iconFile
                    }

                    PanelText {
                        id: title
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.titlesFit
                        width: Math.min(title.implicitWidth, root.titleRoom)
                        elide: Text.ElideRight
                        text: button.modelData.windows.length === 1
                            ? WindowEvents.label(button.modelData.windows[0])
                            : button.modelData.appName
                    }
                }

                // Under the button, in the panel's margin: how many windows
                // the application has, and whether one of them is focused --
                // a long accent bar for the focused one, a short mark per
                // other window. Colour alone is the distinction a person with
                // low vision may not see at all, so the count is shape as
                // well as tint.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height + Math.max(1, Math.round(((root.bar?.thickness ?? 40) - root.buttonHeight) / 2 - 7))
                    spacing: 3

                    Repeater {
                        // Past four the marks stop being countable and start
                        // being noise.
                        model: Math.min(4, button.windowCount)

                        Rectangle {
                            required property int index

                            width: button.isActive && index === 0 ? Math.round(22 * Math.max(0.7, root.unit))
                                                                 : Math.round(6 * Math.max(0.7, root.unit))
                            height: 3
                            radius: 1.5
                            color: button.isActive && index === 0 ? Theme.acc : Theme.alpha(Theme.fg, 0.4)
                        }
                    }
                }
            }
        }
    }

    // One popout, two contents: a button's menu, or the preview.
    popout: Component {
        Item {
            // The loaded contents are Items; the linter only knows they are
            // QObjects, so they are read through a typed alias.
            readonly property Item shownContent: (menuLoader.item ?? previewLoader.item) as Item

            // In menu mode the width is the widget's to state, not the
            // menu's to work out: the rows are as wide as the menu and the
            // menu as wide as the card, so asking the menu how wide it wants
            // to be is a loop. The card's own width is what breaks it.
            implicitWidth: root.popoutMode === "menu" ? root.menuWidth
                                                      : (shownContent?.implicitWidth ?? 1)
            implicitHeight: shownContent?.implicitHeight ?? 1

            Loader {
                id: menuLoader

                // The menu's rows are as wide as the menu, and the menu is as
                // wide as it is given: `popoutWidth` above fixes the card at
                // 262 and this Loader is what passes that on. Without a width
                // here every row laid out 0 wide inside a card the right size,
                // which is a right click that does nothing at all.
                width: parent.width
                active: root.popoutMode === "menu" && root.menuItem !== null
                sourceComponent: TaskMenu {
                    item: root.menuItem
                    entry: WindowsService.entryById(WindowEvents.appIdOf(root.menuItem))
                    pinned: root.menuItem?.pinned === true

                    onLaunch: action => {
                        WindowsService.launch(WindowEvents.appIdOf(root.menuItem), action);
                        root.popoutVisible = false;
                    }
                    onTogglePin: {
                        ConfigStore.set("widgets.tasks.pinned",
                                        WindowEvents.togglePinned(root.pinned, WindowEvents.appIdOf(root.menuItem)));
                        root.popoutVisible = false;
                    }
                    onCloseWindows: {
                        for (const w of root.menuItem?.windows ?? [])
                            WindowsService.close(w.uuid);
                        root.popoutVisible = false;
                    }
                }
            }

            Loader {
                id: previewLoader
                active: root.popoutMode !== "menu"
                sourceComponent: root.preview
            }

            // The card is as tall as whichever is loaded. The menu's height is
            // the sum of its rows, which it only knows once it has a width.
        }
    }

    // The preview.
    //
    // It shows a live picture of the window where the compositor gives one --
    // KWin's screencast protocol, through this project's one compiled part
    // (plugin/) -- and the application's icon where it does not.
    //
    // A group of several windows is a picture each, not a list of titles, and
    // every one of them is a target: hovering a grouped button and then being
    // unable to say which window you meant is the whole complaint against a
    // grouped taskbar, and "click to move through them" is an answer only for
    // somebody who already knows which one is next.
    //
    // The previous note here said a picture was impossible. It was wrong in an
    // instructive way: the protocol is restricted rather than absent, and KWin
    // gives it to a client whose desktop file asks for it by name.
    readonly property Component preview: Component {
        Item {
            id: preview

            readonly property var item: root.previewItem
            readonly property var windows: preview.item?.windows ?? []
            readonly property bool many: preview.windows.length > 1

            // Three across before it wraps. Four Chrome windows in a row is
            // wider than a laptop screen, and a card wider than the screen is
            // clamped -- which puts the cards under a button they did not come
            // from.
            readonly property int columns: Math.min(3, Math.max(1, preview.windows.length))
            readonly property int cellWidth: 176
            readonly property int cellHeight: 99

            implicitWidth: Math.max(260, body.implicitWidth + 24)
            implicitHeight: body.implicitHeight + 14

            // The pointer being on the card is what keeps the card. Declared
            // here rather than on each cell so the gaps between them count as
            // being on it too.
            HoverHandler {
                id: cardHover
                onHoveredChanged: {
                    root.pointerInPopout = cardHover.hovered;
                    if (cardHover.hovered)
                        root.cancelClose();
                    else
                        root.beginClose();
                }
            }

            Column {
                id: body
                anchors.centerIn: parent
                spacing: 8

                // One window: the picture is the card, as big as it is worth
                // drawing, and the title sits under the application below.
                WindowThumbnail {
                    visible: preview.windows.length === 1
                    width: 300
                    height: 169
                    windowId: preview.windows[0]?.uuid ?? ""
                    iconName: preview.item?.iconName ?? ""
                    iconFile: preview.item?.iconFile ?? ""
                    iconScale: 0.3
                    sourceAspect: WindowEvents.aspectOf(preview.windows[0])
                    live: preview.windows.length === 1
                }

                // The application, once, however many windows it has.
                Row {
                    spacing: 12

                    PanelIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 40
                        iconName: preview.item?.iconName ?? ""
                        iconFile: preview.item?.iconFile ?? ""
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        PanelText {
                            text: preview.item?.appName ?? ""
                            font.bold: true
                        }

                        PanelText {
                            visible: text.length > 0
                            text: preview.many
                                ? `${preview.windows.length} windows — pick one`
                                : preview.windows.length === 0 ? "Pinned — click to start it" : ""
                            color: Theme.foregroundInactive
                            font.pixelSize: 11
                        }
                    }
                }

                // Every window it has, each with its own picture and each a
                // target. Only `columns` is set -- see ZoneRow for why setting
                // both goes wrong.
                Grid {
                    visible: preview.many
                    columns: preview.columns
                    spacing: 8

                    Repeater {
                        model: preview.many ? preview.windows : []

                        Rectangle {
                            id: cell

                            required property var modelData
                            required property int index

                            width: preview.cellWidth
                            height: preview.cellHeight + cellTitle.implicitHeight + 14
                            radius: Theme.radiusOf(12)
                            color: cell.modelData.active ? Theme.accC
                                 : cellPointer.hovered ? Theme.s2
                                                       : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                            WindowThumbnail {
                                id: shot
                                x: 4
                                y: 4
                                width: preview.cellWidth - 8
                                height: preview.cellHeight
                                windowId: cell.modelData.uuid ?? ""
                                iconName: preview.item?.iconName ?? ""
                                iconFile: preview.item?.iconFile ?? ""
                                iconScale: 0.4
                                sourceAspect: WindowEvents.aspectOf(cell.modelData)
                                // A picture is a screencast stream, and one
                                // per window is one per window. Eight is more
                                // than anybody picks from at a glance; past
                                // that the cards are icons, which is what a
                                // thumbnail falls back to anyway.
                                live: cell.index < 8
                                opacity: cell.modelData.minimized ? 0.55 : 1
                            }

                            PanelText {
                                id: cellTitle
                                x: 6
                                width: cell.width - 12
                                anchors.top: shot.bottom
                                anchors.topMargin: 4
                                elide: Text.ElideRight
                                text: WindowEvents.label(cell.modelData)
                                color: cell.modelData.minimized ? Theme.foregroundInactive : Theme.foreground
                                font.pixelSize: 11
                                font.italic: cell.modelData.minimized
                            }

                            // Closing a window from its own picture, as every
                            // taskbar preview does. Only under the pointer:
                            // a row of crosses on a card somebody is only
                            // reading is an invitation to lose a window.
                            Rectangle {
                                id: closeButton
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: 20
                                height: 20
                                radius: 10
                                visible: cellPointer.hovered
                                color: closePointer.hovered ? Theme.error : Theme.alpha(Theme.background, 0.75)

                                Glyph {
                                    anchors.centerIn: parent
                                    name: "close"
                                    fallback: "window-close"
                                    size: 13
                                    color: closePointer.hovered ? Theme.errorFg : Theme.foreground
                                }

                                HoverHandler { id: closePointer; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        WindowsService.close(cell.modelData.uuid);
                                        // The card stays: closing one of five
                                        // windows is usually the first of
                                        // several, and a card that vanished
                                        // would make the second a fresh hunt.
                                        // It closes itself when the last one
                                        // goes, because the group does.
                                        root.cancelClose();
                                    }
                                }
                            }

                            HoverHandler { id: cellPointer; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                // The whole cell, not the picture: a target
                                // the size of the thing it stands for.
                                onTapped: {
                                    WindowsService.activate(cell.modelData.uuid);
                                    root.popoutVisible = false;
                                }
                            }
                        }
                    }
                }

                // One window's title, under the picture of it. A group says
                // its titles on the cards above instead.
                Row {
                    visible: preview.windows.length === 1
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 12
                        radius: 1.5
                        color: preview.windows[0]?.active ? Theme.accent : "transparent"
                    }

                    PanelText {
                        id: soleTitle
                        width: Math.min(soleTitle.implicitWidth, 320)
                        elide: Text.ElideRight
                        text: preview.windows[0] ? WindowEvents.label(preview.windows[0]) : ""
                        color: preview.windows[0]?.minimized ? Theme.foregroundInactive : Theme.foreground
                        font.pixelSize: 12
                        font.italic: preview.windows[0]?.minimized === true
                    }
                }
            }
        }
    }
}
