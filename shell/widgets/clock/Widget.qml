// Clock. The first widget, and the proof that a widget needs nothing from the
// panel beyond the three injected properties.

import QtQuick
import Quickshell
import qs.ui.primitives
import qs.domain.theme

BarWidget {
    id: root

    readonly property string timeFormat: root.widgetConfig?.format ?? "HH:mm"
    readonly property bool showDate: root.widgetConfig?.showDate ?? false
    readonly property string dateFormat: root.widgetConfig?.dateFormat ?? "ddd d MMM"

    // Down the side of the screen the time sits over the date, and both are
    // held to the panel's width: side by side, they ran off it.
    readonly property bool vertical: !(root.bar?.horizontal ?? true)
    readonly property real across: (root.bar?.thickness ?? 40) - 4

    // The whole date, in the user's own locale, whatever the panel shows.
    tooltip: root.clock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)

    // Quickshell's shared clock: one timer for the whole shell rather than one
    // per widget instance, and it ticks on the second boundary rather than
    // drifting.
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
    }

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // Only `columns` is set, and never to a column that would stay empty --
    // see ZoneRow.
    Grid {
        id: layout
        anchors.centerIn: parent
        columns: root.vertical || !root.showDate ? 1 : 2
        columnSpacing: 8
        rowSpacing: 2
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        PanelText {
            text: Qt.formatDateTime(root.clock.date, root.timeFormat)
            // Shrinks to fit a narrow side panel rather than overflowing it.
            width: root.vertical ? Math.min(implicitWidth, root.across) : implicitWidth
            fontSizeMode: root.vertical ? Text.HorizontalFit : Text.FixedSize
            minimumPixelSize: 8
            horizontalAlignment: Text.AlignHCenter
        }

        PanelText {
            visible: root.showDate
            color: Theme.foregroundInactive
            font.pixelSize: root.vertical ? 10 : 12
            text: Qt.formatDateTime(root.clock.date, root.dateFormat)
            width: root.vertical ? root.across : implicitWidth
            wrapMode: root.vertical ? Text.WordWrap : Text.NoWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
