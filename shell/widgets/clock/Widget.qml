pragma ComponentBehavior: Bound

// Clock: the time over the date, as the design has it.
//
// 24 or 12 hours, seconds or not, the date or not -- or a Qt format string of
// the person's own in `format`, which then wins. On a thin panel the date sits
// beside the time rather than under it; down the side of the screen there is
// room for the time alone.

import QtQuick
import Quickshell
import qs.ui.primitives
import qs.domain.theme

BarWidget {
    id: root

    readonly property bool hour12: root.widgetConfig?.hour12 ?? false
    readonly property bool showSeconds: root.widgetConfig?.showSeconds ?? false
    readonly property bool showDate: root.widgetConfig?.showDate ?? true
    readonly property string customFormat: root.widgetConfig?.format ?? ""
    readonly property string dateFormat: root.widgetConfig?.dateFormat ?? "ddd d MMM"

    readonly property string timeFormat: root.customFormat.length > 0 ? root.customFormat
        : (root.hour12 ? "h:mm" : "HH:mm") + (root.showSeconds ? ":ss" : "") + (root.hour12 ? " ap" : "")

    readonly property bool vertical: !(root.bar?.horizontal ?? true)
    readonly property real across: (root.bar?.thickness ?? 40) - 8
    readonly property bool dateShown: root.showDate && !root.vertical
    // Two lines need a panel thick enough to hold them.
    readonly property bool stacked: (root.bar?.thickness ?? 40) >= 44

    // The whole date, in the user's own locale, whatever the panel shows.
    tooltip: root.clock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)

    // Quickshell's shared clock: one timer for the whole shell rather than one
    // per widget instance, and it ticks on the second boundary rather than
    // drifting. Seconds only when they are shown.
    readonly property SystemClock clock: SystemClock {
        precision: root.timeFormat.indexOf("s") >= 0 ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property real k: Math.max(0.7, root.unit)

    // A click opens the month.
    popoutWidth: 348
    popoutPadding: 22
    popout: Component {
        CalendarPopout {
            clock: root.clock
            timeFormat: root.timeFormat
            onDone: root.popoutVisible = false
        }
    }

    function handleActivate(button) {
        if (button === Qt.LeftButton)
            root.popoutVisible = !root.popoutVisible;
    }

    implicitWidth: root.vertical ? root.across : layout.implicitWidth + 2 * Math.round(14 * root.k)
    implicitHeight: root.vertical ? layout.implicitHeight + 12 : Math.max(24, Math.round(44 * root.unit))

    Rectangle {
        anchors.fill: parent
        radius: Math.round(13 * root.k)
        color: root.hovered || root.popoutVisible ? Theme.s2 : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    // Only `columns` is set, and never to a column that would stay empty --
    // see ZoneRow.
    Grid {
        id: layout
        anchors.centerIn: parent
        columns: root.dateShown && !root.stacked ? 2 : 1
        columnSpacing: 8
        rowSpacing: 0
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        PanelText {
            text: Qt.formatDateTime(root.clock.date, root.timeFormat)
            // Shrinks to fit a narrow side panel rather than overflowing it.
            width: root.vertical ? Math.min(implicitWidth, root.across) : implicitWidth
            fontSizeMode: root.vertical ? Text.HorizontalFit : Text.FixedSize
            minimumPixelSize: 8
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: root.vertical ? 13 : Math.round(14 * Math.min(1, Math.max(0.9, root.unit)))
            font.weight: Font.Medium
            lineHeight: 1.1
        }

        PanelText {
            visible: root.dateShown
            color: Theme.mut
            font.pixelSize: 12
            lineHeight: 1.1
            text: Qt.formatDateTime(root.clock.date, root.dateFormat)
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
