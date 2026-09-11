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
    readonly property int iconSize: root.configuredIconSize > 0
        ? root.configuredIconSize
        : Math.max(12, Math.min(48, root.bar.thickness - 14))

    readonly property bool groupByApp: root.widgetConfig?.groupByApp ?? true

    // Desktop entry ids, in the order they sit on the taskbar.
    readonly property var pinned: root.widgetConfig?.pinned ?? []

    // Only the windows on this panel's own monitor, when asked -- Windows'
    // "show taskbar apps on the taskbar where the window is open". A window
    // with no monitor named (a script older than that field) is shown
    // everywhere rather than nowhere.
    readonly property bool thisScreenOnly: root.widgetConfig?.thisScreenOnly ?? false
    readonly property var windowsHere: root.thisScreenOnly
        ? WindowsService.windows.filter(w => !w.output || w.output === root.screenName)
        : WindowsService.windows

    // One item per application when grouping, one per window otherwise. Both
    // are the same shape -- a list of {windows, appName, icon...} -- so the row
    // below does not care which it is drawing.
    readonly property var running: root.groupByApp
        ? (root.thisScreenOnly ? WindowsService.groupsOf(root.windowsHere) : WindowsService.groups)
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

    // One button's width. Square for icons only, wider when titles are shown.
    readonly property int buttonWidth: root.showTitles ? root.maxWidth
                                                       : Math.max(24, root.iconSize + 14)
    readonly property int buttonHeight: Math.max(18, root.bar.thickness - 10)
    readonly property int spacing: 4
    readonly property int stride: root.buttonWidth + root.spacing

    // Which button the pointer is over, or -1. The panel reports the position
    // along the widget; turning that into an index is arithmetic rather than a
    // handler per button.
    property int hoveredIndex: -1

    // What the popout shows: the preview while the pointer is over a button,
    // or a button's menu after a right click. The menu stays put while the
    // pointer travels to it, and a click anywhere else closes it; the preview
    // follows the pointer and closes by itself.
    property string popoutMode: "preview"
    property var menuItem: null

    wantsHover: true
    popoutClosesOnOutsideClick: root.popoutMode === "menu"

    // How long a button flashes once its window asks for attention, before
    // settling to a steady tint.
    readonly property int flashMs: 6000

    implicitWidth: row.implicitWidth
    implicitHeight: root.bar.thickness

    function handleHover(position, horizontal) {
        const index = Math.floor(position / root.stride);
        root.hoveredIndex = (index >= 0 && index < root.items.length) ? index : -1;

        if (root.popoutMode === "menu")
            return;
        if (root.hoveredIndex >= 0) {
            root.popoutVisible = true;
            root.requestPopout("tasks", root.hoveredIndex * root.stride + root.buttonWidth / 2);
        } else {
            root.popoutVisible = false;
        }
    }

    // `dismissPopout` is a signal on the base type -- the panel emits it when
    // the pointer leaves -- so this handles it rather than defining a function
    // of the same name, which is a silent clash at load time. The pointer
    // leaving is how it reaches an open menu, so the menu stays.
    onDismissPopout: {
        root.hoveredIndex = -1;
        if (root.popoutMode !== "menu")
            root.popoutVisible = false;
    }

    // However it closed -- chosen from, clicked away from, replaced by another
    // popout -- the next one opens as the preview again.
    onPopoutVisibleChanged: {
        if (!root.popoutVisible) {
            root.popoutMode = "preview";
            root.menuItem = null;
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
        root.requestPopout("tasks", root.items.indexOf(item) * root.stride + root.buttonWidth / 2);
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

        Repeater {
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

                width: root.buttonWidth
                height: root.buttonHeight
                radius: 5

                // A pinned application that is not running sits on the panel
                // itself, the way Windows draws one: no tile until hovered.
                color: button.isActive  ? PlasmaColors.alpha(PlasmaColors.accent, 0.28)
                     : button.isHovered ? PlasmaColors.hoverBackground
                     : button.windowCount === 0 ? "transparent"
                                        : PlasmaColors.backgroundAlternate

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
                    color: PlasmaColors.neutral
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
                    anchors.centerIn: parent
                    spacing: 6

                    PanelIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: root.iconSize
                        iconName: button.modelData.iconName
                        iconFile: button.modelData.iconFile
                    }

                    PanelText {
                        id: title
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showTitles
                        width: Math.min(title.implicitWidth, root.maxWidth - root.iconSize - 24)
                        elide: Text.ElideRight
                        text: button.modelData.windows.length === 1
                            ? WindowEvents.label(button.modelData.windows[0])
                            : button.modelData.appName
                        font.bold: button.isActive
                    }
                }

                // How many windows the application has, and which is active,
                // in one mark: a dash per window, filled for the active one.
                // Colour alone is the distinction a person with low vision may
                // not see at all, so the count is shape as well as tint.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    spacing: 2

                    Repeater {
                        // Past four the marks stop being countable and start
                        // being noise.
                        model: Math.min(4, button.windowCount)

                        Rectangle {
                            required property int index

                            width: button.windowCount === 1 ? button.width * 0.5 : 4
                            height: 2
                            radius: 1
                            color: button.isActive ? PlasmaColors.accent
                                                   : PlasmaColors.alpha(PlasmaColors.foreground, 0.35)
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

            implicitWidth: shownContent?.implicitWidth ?? 1
            implicitHeight: shownContent?.implicitHeight ?? 1

            Loader {
                id: menuLoader
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
        }
    }

    // The preview.
    //
    // It is not a thumbnail, and cannot be one here. Window images come from
    // the plasma-window-management protocol, which Quickshell does not bind;
    // KWin's other route, ScreenShot2.CaptureWindow, refuses us outright with
    // "the process is not authorized to take a screenshot" -- it is restricted
    // to callers KWin allows, and we are not one. So the preview shows what is
    // actually knowable, at a size worth hovering for: the application's own
    // icon, its real name rather than its window class, the full title, and
    // the state the window is in.
    readonly property Component preview: Component {
        Item {
            id: preview

            readonly property var item: root.items[root.hoveredIndex] ?? null
            readonly property var windows: preview.item?.windows ?? []

            implicitWidth: Math.max(260, body.implicitWidth + 24)
            implicitHeight: body.implicitHeight + 14

            Column {
                id: body
                anchors.centerIn: parent
                spacing: 8

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
                            text: preview.windows.length > 1
                                ? `${preview.windows.length} windows — click to move through them`
                                : preview.windows.length === 0 ? "Pinned — click to start it" : ""
                            color: PlasmaColors.foregroundInactive
                            font.pixelSize: 11
                        }
                    }
                }

                // Then every window it has, which is the part a grouped button
                // otherwise hides. KDE puts a thumbnail beside each of these;
                // the protocol that would give us one is not offered to us, so
                // this is the title and the state instead.
                Repeater {
                    model: preview.windows

                    Row {
                        id: line

                        required property var modelData

                        spacing: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 12
                            radius: 1.5
                            color: line.modelData.active ? PlasmaColors.accent : "transparent"
                        }

                        PanelText {
                            id: lineTitle
                            width: Math.min(lineTitle.implicitWidth, 320)
                            elide: Text.ElideRight
                            text: WindowEvents.label(line.modelData)
                            color: line.modelData.minimized ? PlasmaColors.foregroundInactive
                                                            : PlasmaColors.foreground
                            font.pixelSize: 12
                            font.italic: line.modelData.minimized
                        }
                    }
                }
            }
        }
    }
}
