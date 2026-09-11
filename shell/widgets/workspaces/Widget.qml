pragma ComponentBehavior: Bound

// KWin virtual desktops.
//
// KWin owns virtual desktops, so this shows and switches them rather than
// inventing a parallel notion of workspaces. Adding and removing desktops is
// KWin's too -- the widget only asks.

import QtQuick
import qs.ui.primitives
import qs.domain.desktops
import qs.domain.theme

BarWidget {
    id: root

    readonly property bool showNames: root.widgetConfig?.showNames ?? false

    // Scrolling through desktops is a convenience, not everyone's preference:
    // it is easy to trigger by accident while reaching past the panel.
    wantsWheel: root.widgetConfig?.scrollToSwitch ?? true

    function handleWheel(delta) {
        Desktops.switchBy(delta > 0 ? -1 : 1);
    }

    // Pills run along the panel and the current one grows along it too, on
    // either axis. Names are left off down the side of the screen: they would
    // be as wide as the panel is thick.
    readonly property bool vertical: !(root.bar?.horizontal ?? true)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Only `columns` is set -- see ZoneRow.
    Grid {
        id: row
        anchors.centerIn: parent
        spacing: 4
        columns: root.vertical ? 1 : Math.max(1, Desktops.count)
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            model: Desktops.desktops

            Rectangle {
                id: pill

                required property var modelData
                readonly property bool active: pill.modelData.id === Desktops.currentId
                readonly property real length: Math.max(label.visible ? label.implicitWidth + 12 : 0,
                                                        pill.active ? 26 : 14)

                implicitWidth: root.vertical ? 14 : pill.length
                implicitHeight: root.vertical ? pill.length : 14
                radius: Math.min(width, height) / 2

                color: pill.active ? PlasmaColors.accent
                                   : (hover.hovered ? PlasmaColors.hoverBackground
                                                    : PlasmaColors.alpha(PlasmaColors.foreground, 0.25))

                Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on implicitHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }

                PanelText {
                    id: label
                    anchors.centerIn: parent
                    visible: root.showNames && !root.vertical
                    text: pill.modelData.name ?? ""
                    font.pixelSize: 11
                    color: pill.active ? PlasmaColors.background : PlasmaColors.foreground
                }

                HoverHandler { id: hover }

                TapHandler {
                    onTapped: Desktops.switchTo(pill.modelData.id)
                }
            }
        }
    }
}
