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
    readonly property int iconSize: root.widgetConfig?.iconSize ?? 18
    readonly property int maxWidth: root.widgetConfig?.maxWidth ?? 180

    readonly property var windows: WindowsService.windows

    // One button's width. Square for icons only, wider when titles are shown.
    readonly property int buttonWidth: root.showTitles ? root.maxWidth
                                                       : Math.max(24, root.iconSize + 14)
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
        root.hoveredIndex = (index >= 0 && index < root.windows.length) ? index : -1;

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
        const window = root.windows[root.hoveredIndex];
        if (window)
            WindowsService.activate(window.uuid);
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

        Repeater {
            model: root.windows

            Rectangle {
                id: button

                required property var modelData
                required property int index

                readonly property bool isActive: button.modelData.active === true
                readonly property bool isMinimized: button.modelData.minimized === true
                readonly property bool isHovered: button.index === root.hoveredIndex

                width: root.buttonWidth
                height: Math.max(20, root.bar.thickness - 10)
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
                        iconName: WindowEvents.iconName(button.modelData)
                    }

                    PanelText {
                        id: title
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showTitles
                        width: Math.min(title.implicitWidth, root.maxWidth - root.iconSize - 24)
                        elide: Text.ElideRight
                        text: WindowEvents.label(button.modelData)
                        font.bold: button.isActive
                    }
                }

                // The active window gets a line under it as well as a tint:
                // colour alone is the one distinction a person with low vision
                // may not see at all.
                Rectangle {
                    visible: button.isActive
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: parent.width * 0.5
                    height: 2
                    radius: 1
                    color: PlasmaColors.accent
                }
            }
        }
    }

    // The preview. A thumbnail is not possible here: window images come from
    // the plasma-window-management protocol, which Quickshell does not bind and
    // KWin exposes over no other interface. So it shows what is actually
    // knowable -- the application, the full title, and what state the window is
    // in.
    popout: Component {
        Item {
            id: preview

            readonly property var window: root.windows[root.hoveredIndex] ?? null

            implicitWidth: Math.max(220, body.implicitWidth + 20)
            implicitHeight: body.implicitHeight + 8

            Row {
                id: body
                anchors.centerIn: parent
                spacing: 10

                PanelIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 32
                    iconName: WindowEvents.iconName(preview.window)
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    PanelText {
                        id: previewTitle
                        width: Math.min(previewTitle.implicitWidth, 320)
                        elide: Text.ElideRight
                        text: preview.window?.title ?? ""
                        font.bold: true
                    }

                    PanelText {
                        text: preview.window
                            ? `${preview.window.appId} — ${preview.window.minimized ? "minimised"
                                                          : preview.window.active ? "active" : "open"}`
                            : ""
                        color: PlasmaColors.foregroundInactive
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
