pragma ComponentBehavior: Bound

// System tray.
//
// Quickshell runs the StatusNotifierHost, so this works on KWin with no
// KDE-specific code. Nothing here touches org.kde.StatusNotifierWatcher.

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.ui.primitives

BarWidget {
    id: root

    readonly property int iconSize: root.widgetConfig?.iconSize ?? 18
    readonly property var hidden: root.widgetConfig?.hidden ?? []

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: ScriptModel {
                values: SystemTray.items.values.filter(i => !root.hidden.includes(i.id))
            }

            Item {
                id: entry

                required property SystemTrayItem modelData

                implicitWidth: root.iconSize
                implicitHeight: root.iconSize

                PanelIcon {
                    anchors.fill: parent
                    // The item's own icon wins; its id is the fallback so a
                    // badly-behaved application still shows something.
                    source: entry.modelData.icon
                    fallbackName: entry.modelData.id
                    opacity: entry.modelData.status === Status.Passive ? 0.5 : 1
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onClicked: event => {
                        // Right-click opens the application's own menu. Rendering
                        // that menu is a later piece of work, so for now the
                        // secondary action is used, which most applications map
                        // to something sensible.
                        if (event.button === Qt.LeftButton)
                            entry.modelData.activate();
                        else
                            entry.modelData.secondaryActivate();
                    }
                }
            }
        }
    }
}
