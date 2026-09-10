pragma ComponentBehavior: Bound

// The open windows.
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
// A click activates; KWin does the rest. Nothing here moves, closes or
// rearranges a window.

import QtQuick
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

    // One button per application when grouping, one per window otherwise. Both
    // are the same shape -- a list of {windows, appName, icon...} -- so the row
    // below does not care which it is drawing.
    readonly property var items: root.groupByApp
        ? WindowsService.groups
        : WindowsService.windows.map(w => ({
            key: w.uuid,
            appName: WindowsService.appNameFor(w),
            windows: [w],
            active: w.active === true,
            iconName: WindowsService.iconFor(w),
            iconFile: WindowsService.iconFileFor(w)
        }))

    // One button's width. Square for icons only, wider when titles are shown.
    readonly property int buttonWidth: root.showTitles ? root.maxWidth
                                                       : Math.max(24, root.iconSize + 14)
    readonly property int buttonHeight: Math.max(18, root.bar.thickness - 10)
    readonly property int spacing: 4

    // Which button the pointer is over, or -1. The panel reports the position
    // along the widget; turning that into an index is arithmetic rather than a
    // handler per button.
    property int hoveredIndex: -1

    wantsHover: true

    implicitWidth: row.implicitWidth
    implicitHeight: root.bar.thickness

    function handleHover(position, horizontal) {
        const stride = root.buttonWidth + root.spacing;
        const index = Math.floor(position / stride);
        root.hoveredIndex = (index >= 0 && index < root.items.length) ? index : -1;

        if (root.hoveredIndex >= 0) {
            root.popoutVisible = true;
            root.requestPopout("tasks", root.hoveredIndex * stride + root.buttonWidth / 2);
        } else {
            root.popoutVisible = false;
        }
    }

    // `dismissPopout` is a signal on the base type -- the panel emits it when
    // the pointer leaves -- so this handles it rather than defining a function
    // of the same name, which is a silent clash at load time.
    onDismissPopout: {
        root.hoveredIndex = -1;
        root.popoutVisible = false;
    }

    function handleActivate(button) {
        const item = root.items[root.hoveredIndex];
        if (item)
            WindowsService.activateGroup(item);
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
                // one visible window means the application is on screen.
                readonly property bool isMinimized: button.modelData.windows.every(w => w.minimized)
                readonly property bool isHovered: button.index === root.hoveredIndex
                readonly property int windowCount: button.modelData.windows.length

                width: root.buttonWidth
                height: root.buttonHeight
                radius: 5

                color: button.isActive  ? PlasmaColors.alpha(PlasmaColors.accent, 0.28)
                     : button.isHovered ? PlasmaColors.hoverBackground
                                        : PlasmaColors.backgroundAlternate

                // A minimised window is still there and still clickable; it is
                // dimmed rather than hidden, which is the whole difference
                // between a task list and a window list.
                opacity: button.isMinimized ? 0.55 : 1

                Behavior on color { ColorAnimation { duration: 100 } }

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
    popout: Component {
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
                            visible: preview.windows.length > 1
                            text: `${preview.windows.length} windows — click to move through them`
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
