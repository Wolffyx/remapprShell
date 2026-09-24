pragma ComponentBehavior: Bound

// The sidebar's card for the weather. Folded, now; open, the next hours and
// the next days.

import QtQuick
import Quickshell
import qs.domain.theme
import qs.domain.weather
import qs.domain.weather.forecast
import qs.ui.primitives

SidebarCard {
    id: weatherCard

    // The sidebar's clock, which every card that tells the time shares.
    required property SystemClock clock

    cardId: "weather"
    title: "Weather"
    glyph: WeatherStatus.condition.glyph

    // One hour or one day of the forecast, as a column of three lines.
    component Moment: Column {
        id: moment
        property string when: ""
        property string glyph: ""
        property string value: ""
        property string second: ""
        width: 52
        spacing: 4

        PanelText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: moment.when
            font.pixelSize: 11
            color: Theme.mut
        }

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            name: moment.glyph
            size: 20
            color: Theme.acc
        }

        PanelText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: moment.value
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        PanelText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: moment.second.length > 0
            text: moment.second
            font.pixelSize: 10
            color: Theme.mut
        }
    }

    content: [
        // Off, or not yet answered: one line that says which, rather
        // than an empty card that looks broken.
        Hint {
            visible: !WeatherStatus.ready
            text: !WeatherStatus.enabled
                ? "Off. Settings → Weather turns it on; it asks Open-Meteo for a forecast and nothing else."
                : (WeatherStatus.error.length > 0 ? WeatherStatus.error : "Asking…")
            lineHeight: 1
        },

        Row {
            visible: WeatherStatus.ready
            width: parent.width
            spacing: 14

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: WeatherStatus.condition.glyph
                size: 44
                color: Theme.acc
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 58

                PanelText {
                    text: WeatherStatus.temperatureText
                    font.pixelSize: 24
                    font.weight: Font.Medium
                }

                PanelText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: [WeatherStatus.condition.label, WeatherStatus.placeName].filter(s => s).join(" · ")
                    font.pixelSize: 12
                    color: Theme.mut
                }
            }
        }
    ]

    extra: Column {
        spacing: 12

        Row {
            visible: WeatherStatus.ready
            width: parent.width
            spacing: 16

            PanelText {
                text: WeatherStatus.current
                    ? `Feels ${Forecast.degrees(WeatherStatus.current.feelsLike, WeatherStatus.temperatureUnit)}` : ""
                font.pixelSize: 12
                color: Theme.mut
            }
            PanelText {
                text: WeatherStatus.current ? `Humidity ${Math.round(WeatherStatus.current.humidity)}%` : ""
                font.pixelSize: 12
                color: Theme.mut
            }
            PanelText {
                text: WeatherStatus.current
                    ? `Wind ${Math.round(WeatherStatus.current.wind)} ${WeatherStatus.forecast?.windUnit ?? ""}` : ""
                font.pixelSize: 12
                color: Theme.mut
            }
        }

        // The next hours, across.
        Flickable {
            visible: WeatherStatus.ready
            width: parent.width
            height: 76
            contentWidth: hours.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            clip: true

            Row {
                id: hours
                spacing: 4

                Repeater {
                    model: WeatherStatus.hours.slice(0, 12)

                    Moment {
                        required property var modelData
                        when: Qt.formatDateTime(new Date(modelData.when), "HH:mm")
                        glyph: Forecast.describe(modelData.code, modelData.isDay).glyph
                        value: Forecast.degrees(modelData.temperature, "°")
                        second: modelData.rain > 0 ? `${Math.round(modelData.rain)}%` : ""
                    }
                }
            }
        }

        // And the days.
        Column {
            visible: WeatherStatus.ready
            width: parent.width
            spacing: 8

            Repeater {
                model: WeatherStatus.days.slice(0, 5)

                Item {
                    id: line
                    required property var modelData
                    width: parent.width
                    height: 20

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 70
                        text: Forecast.dayName(line.modelData.when, weatherCard.clock.date.getTime(), Qt.locale())
                        font.pixelSize: 12
                        color: Theme.mut
                    }

                    Glyph {
                        x: 74
                        anchors.verticalCenter: parent.verticalCenter
                        name: Forecast.describe(line.modelData.code, true).glyph
                        size: 16
                        color: Theme.acc
                    }

                    PanelText {
                        x: 100
                        anchors.verticalCenter: parent.verticalCenter
                        visible: line.modelData.rain > 0
                        text: `${Math.round(line.modelData.rain)}%`
                        font.pixelSize: 11
                        color: Theme.mut
                    }

                    PanelText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Forecast.degrees(line.modelData.high, "°")} / ${Forecast.degrees(line.modelData.low, "°")}`
                        font.pixelSize: 12
                    }
                }
            }
        }

        PanelText {
            visible: WeatherStatus.ready
            width: parent.width
            text: WeatherStatus.fetchedAt > 0
                ? `Open-Meteo · ${Qt.formatDateTime(new Date(WeatherStatus.fetchedAt), "HH:mm")}` : ""
            font.pixelSize: 10
            color: Theme.mut
        }
    }
}
