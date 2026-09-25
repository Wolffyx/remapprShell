pragma ComponentBehavior: Bound

// The sidebar's card for the day. Folded, the date and how long the machine
// has been up; open, the month -- with the forecast on the days it is known
// for.

import QtQuick
import Quickshell
import qs.domain.session
import qs.domain.theme
import qs.domain.weather
import qs.domain.weather.forecast
import qs.ui.primitives

SidebarCard {
    id: dayCard

    // The sidebar's clock, which every card that tells the time shares.
    required property SystemClock clock

    cardId: "day"
    title: "Today"
    glyph: "calendar_month"

    readonly property var chosen: Forecast.dayAt(WeatherStatus.days, dayCard.picked.getTime())
    property date picked: dayCard.clock.date

    content: [
        Row {
            width: parent.width
            spacing: 16

            Column {
                anchors.verticalCenter: parent.verticalCenter

                PanelText {
                    text: dayCard.clock.date.toLocaleDateString(Qt.locale(), "dddd")
                    font.pixelSize: 20
                    font.weight: Font.Medium
                }

                PanelText {
                    // The weekday is the line above.
                    text: [dayCard.clock.date.toLocaleDateString(Qt.locale(), "d MMMM yyyy"), Session.uptime].filter(s => s).join(" · ")
                    font.pixelSize: 12
                    color: Theme.mut
                }
            }
        }
    ]

    extra: Column {
        spacing: 12

        MonthGrid {
            id: month
            width: parent.width
            now: dayCard.clock.date
            cellHeight: 34
            dayDiameter: 30
            dayFontSize: 13
            selected: dayCard.picked
            // The forecast, on the days there is one for: five days out,
            // which is all Open-Meteo is asked for.
            badgeFor: cell => {
                const d = Forecast.dayAt(WeatherStatus.days, new Date(cell.year, cell.month, cell.day).getTime());
                return d ? Forecast.describe(d.code, true).glyph : "";
            }
            onPicked: cell => dayCard.picked = new Date(cell.year, cell.month, cell.day)
        }

        // What the chosen day's weather is, when it is one the forecast
        // reaches. Nothing at all for a day in April.
        Row {
            visible: dayCard.chosen !== null
            width: parent.width
            spacing: 10

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: dayCard.chosen ? Forecast.describe(dayCard.chosen.code, true).glyph : ""
                size: 22
                color: Theme.acc
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                text: dayCard.chosen
                    ? `${dayCard.picked.toLocaleDateString(Qt.locale(), "ddd d MMM")} · ${Forecast.describe(dayCard.chosen.code, true).label}`
                    : ""
                font.pixelSize: 12
                color: Theme.mut
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                text: dayCard.chosen
                    ? `${Forecast.degrees(dayCard.chosen.high, WeatherStatus.temperatureUnit)} / ${Forecast.degrees(dayCard.chosen.low, "")}`
                    : ""
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }
}
