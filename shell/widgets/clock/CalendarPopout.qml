pragma ComponentBehavior: Bound

// The clock's popout: the time, the whole date, and the month.
//
// Weeks start on the locale's first day. Arrows move by a month and the
// month's name goes back to today's. Events and holidays are Plasma's --
// its calendar has the plugins for them -- so a button opens that.

import QtQuick
import qs.domain.calendar
import qs.domain.theme
import qs.platform.kde
import qs.ui.primitives
import qs.ui.controls

Column {
    id: cal

    // The shared clock, and the format the panel shows the time in.
    required property var clock
    required property string timeFormat
    signal done

    readonly property var locale: Qt.locale()
    readonly property int firstDay: cal.locale.firstDayOfWeek
    readonly property date now: cal.clock.date

    property int year: cal.now.getFullYear()
    property int month: cal.now.getMonth()

    function turnMonth(delta) {
        const m = Calendar.shift(cal.year, cal.month, delta);
        cal.year = m.year;
        cal.month = m.month;
    }

    function backToToday() {
        cal.year = cal.now.getFullYear();
        cal.month = cal.now.getMonth();
    }

    readonly property var weeks: Calendar.weeks(cal.year, cal.month, cal.firstDay)

    // How wide it is belongs to the widget: `popoutWidth`. The Loader
    // anchors this to fill the card, so a width set here would be
    // overwritten -- which left the card as wide as the longest line of
    // text in it, a different size in every locale.
    spacing: 0

    PanelText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: Qt.formatDateTime(cal.now, cal.timeFormat)
        font.pixelSize: 52
        font.weight: Font.Light
        font.letterSpacing: -1
    }

    PanelText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        topPadding: 6
        text: cal.now.toLocaleDateString(cal.locale, Locale.LongFormat)
        font.pixelSize: 14
        color: Theme.mut
    }

    Item { width: 1; height: 20 }

    Item {
        width: parent.width
        height: 34

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${cal.locale.standaloneMonthName(cal.month, Locale.LongFormat)} ${cal.year}`
            font.pixelSize: 15
            font.weight: Font.Medium

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: cal.backToToday() }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            IconButton {
                glyph: "chevron_left"
                iconName: "go-previous"
                color: Theme.mut
                onActivated: cal.turnMonth(-1)
            }

            IconButton {
                glyph: "chevron_right"
                iconName: "go-next"
                color: Theme.mut
                onActivated: cal.turnMonth(1)
            }
        }
    }

    Item { width: 1; height: 8 }

    Row {
        width: parent.width

        Repeater {
            model: Calendar.weekdayOrder(cal.firstDay)

            PanelText {
                required property int modelData
                width: cal.width / 7
                height: 28
                horizontalAlignment: Text.AlignHCenter
                text: cal.locale.standaloneDayName(modelData, Locale.NarrowFormat)
                font.pixelSize: 12
                color: Theme.mut
            }
        }
    }

    Repeater {
        model: cal.weeks

        Row {
            id: week
            required property var modelData
            width: cal.width

            Repeater {
                model: week.modelData

                Item {
                    id: cell

                    required property var modelData
                    readonly property bool today: Calendar.isToday(cell.modelData, cal.now)

                    width: cal.width / 7
                    height: 38

                    Rectangle {
                        anchors.centerIn: parent
                        width: 34
                        height: 34
                        radius: Theme.radiusOf(17)
                        color: cell.today ? Theme.acc : "transparent"
                    }

                    PanelText {
                        anchors.centerIn: parent
                        text: cell.modelData.day
                        font.pixelSize: 14
                        color: cell.today ? Theme.accFg : Theme.fg
                        opacity: cell.modelData.inMonth ? 1 : 0.35
                    }
                }
            }
        }
    }

    Item { width: 1; height: 14 }

    TextButton {
        glyph: "event"
        iconName: "view-calendar"
        text: "Events and holidays…"
        onActivated: {
            PlasmaApplets.open("org.kde.plasma.digitalclock");
            cal.done();
        }
    }
}
