pragma ComponentBehavior: Bound

// The open windows.
//
// A click activates; KWin does the rest. Nothing here moves, closes or
// rearranges a window -- this is a view of what KWin already knows, and the
// one action it offers goes through KWin's own runner.
//
// It draws nothing at all when the window list is off, rather than showing a
// message or a placeholder. A panel widget explaining its own configuration is
// clutter on the one surface that has none to spare; `rmpr doctor` says it
// instead, where there is room for the reason and the command.

import QtQuick
import qs.domain.theme
import qs.domain.windows
import qs.domain.windows.events
import qs.ui.primitives

BarWidget {
    id: root

    readonly property bool showTitles: root.widgetConfig?.showTitles ?? true
    readonly property int maxWidth: root.widgetConfig?.maxWidth ?? 180
    readonly property int iconSize: root.widgetConfig?.iconSize ?? 18

    implicitWidth: row.implicitWidth
    implicitHeight: root.bar.thickness

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: WindowsService.windows

            Rectangle {
                id: button

                required property var modelData

                readonly property bool isActive: button.modelData.active === true
                readonly property bool isMinimized: button.modelData.minimized === true

                width: Math.min(root.maxWidth, content.implicitWidth + 16)
                height: Math.max(20, (root.bar.thickness) - 10)
                radius: 5

                color: button.isActive ? PlasmaColors.alpha(PlasmaColors.accent, 0.28)
                     : hover.hovered  ? PlasmaColors.hoverBackground
                                      : PlasmaColors.backgroundAlternate

                // A minimised window is still there and still clickable; it is
                // dimmed rather than hidden, which is the whole difference
                // between a task list and a window list.
                opacity: button.isMinimized ? 0.55 : 1

                Row {
                    id: content
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
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

                HoverHandler { id: hover }
                TapHandler {
                    onTapped: WindowsService.activate(button.modelData.uuid)
                }
            }
        }
    }
}
