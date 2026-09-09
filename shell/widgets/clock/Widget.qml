// Clock. The first widget, and the proof that a widget needs nothing from the
// panel beyond the three injected properties.

import QtQuick
import Quickshell
import qs.ui.primitives

BarWidget {
    id: root

    readonly property string timeFormat: root.widgetConfig?.format ?? "HH:mm"
    readonly property bool showDate: root.widgetConfig?.showDate ?? false
    readonly property string dateFormat: root.widgetConfig?.dateFormat ?? "ddd d MMM"

    // Quickshell's shared clock: one timer for the whole shell rather than one
    // per widget instance, and it ticks on the second boundary rather than
    // drifting.
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
    }

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            font.pixelSize: 13
            text: Qt.formatDateTime(root.clock.date, root.timeFormat)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showDate
            color: Qt.rgba(1, 1, 1, 0.65)
            font.pixelSize: 12
            text: Qt.formatDateTime(root.clock.date, root.dateFormat)
        }
    }
}
