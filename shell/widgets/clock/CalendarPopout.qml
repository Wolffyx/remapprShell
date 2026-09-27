pragma ComponentBehavior: Bound

// The clock's popout: the time, the whole date, the month, and the weather.
//
// Weeks start on the locale's first day. Arrows move by a month and the
// month's name goes back to today's. Events and holidays are Plasma's --
// its calendar has the plugins for them -- so a button opens that.
//
// The grid itself is qs.ui.primitives' MonthGrid, shared with the sidebar's
// day card. The days the forecast reaches carry its glyph under the number,
// and choosing one says what that day is going to do -- which is the whole of
// "the weather, on the calendar". With `weather.enabled` off none of it is
// drawn and this is the calendar it always was.

import QtQuick
import qs.domain.calendar
import qs.domain.theme
import qs.domain.weather
import qs.domain.weather.forecast
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

    // The day whose forecast is shown under the grid: today until another is
    // chosen.
    property date picked: cal.now
    readonly property var forecast: Forecast.dayAt(WeatherStatus.days, cal.picked.getTime())

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

    MonthGrid {
        id: grid
        width: parent.width
        locale: cal.locale
        firstDay: cal.firstDay
        now: cal.now
        year: cal.year
        month: cal.month
        selected: cal.picked
        badgeFor: cell => {
            const day = Forecast.dayAt(WeatherStatus.days, new Date(cell.year, cell.month, cell.day).getTime());
            return day ? Forecast.describe(day.code, true).glyph : "";
        }
        onPicked: cell => cal.picked = new Date(cell.year, cell.month, cell.day)
    }

    Item { width: 1; height: 10 }

    // What the chosen day is going to do. Only for the days the forecast
    // reaches -- five of them -- so most of a month says nothing, which is
    // honest.
    Rectangle {
        visible: WeatherStatus.enabled && cal.forecast !== null
        width: parent.width
        height: visible ? 52 : 0
        radius: Theme.radiusOf(14)
        color: Theme.alpha(Theme.fg, 0.05)

        Glyph {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            name: cal.forecast ? Forecast.describe(cal.forecast.code, true).glyph : ""
            size: 26
            color: Theme.acc
        }

        Column {
            x: 50
            anchors.verticalCenter: parent.verticalCenter

            PanelText {
                text: cal.forecast
                    ? `${Forecast.degrees(cal.forecast.high, WeatherStatus.temperatureUnit)} / ${Forecast.degrees(cal.forecast.low, "")}`
                    : ""
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            PanelText {
                text: cal.forecast
                    ? [Forecast.describe(cal.forecast.code, true).label,
                       cal.forecast.rain > 0 ? `${Math.round(cal.forecast.rain)}% rain` : ""].filter(s => s).join(" · ")
                    : ""
                font.pixelSize: 11
                color: Theme.mut
            }
        }

        PanelText {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: cal.picked.toLocaleDateString(cal.locale, "ddd d MMM")
            font.pixelSize: 11
            color: Theme.mut
        }
    }

    Item { visible: WeatherStatus.enabled && cal.forecast !== null; width: 1; height: 10 }

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
