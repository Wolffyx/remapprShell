pragma ComponentBehavior: Bound

// The weather on the panel: what it is doing now, and a forecast in the
// popout.
//
// Absent from the panel entirely while `weather.enabled` is off, because this
// is the one widget that reaches the internet and a widget that cannot answer
// is worse than no widget. WeatherStatus holds the fetching and the cache;
// Forecast holds the arithmetic; this only draws.

import QtQuick
import qs.domain.theme
import qs.domain.weather
import qs.domain.weather.forecast
import qs.ui.controls
import qs.ui.primitives

BarWidget {
    id: root

    readonly property bool showTemperature: root.widgetConfig?.showTemperature ?? true
    readonly property bool showPlace: root.widgetConfig?.showPlace ?? false
    readonly property int days: root.widgetConfig?.days ?? 5

    present: WeatherStatus.enabled

    tooltip: WeatherStatus.ready
        ? [WeatherStatus.condition.label, WeatherStatus.temperatureText, WeatherStatus.placeName]
            .filter(s => s).join(" · ")
        : (WeatherStatus.error.length > 0 ? WeatherStatus.error : "Asking for a forecast…")

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function handleActivate(button) {
        root.popoutVisible = !root.popoutVisible;
        if (root.popoutVisible)
            WeatherStatus.refresh(false);
    }

    BarButton {
        id: button
        thickness: root.bar?.thickness ?? 40
        vertical: !(root.bar?.horizontal ?? true)
        hovered: root.hovered
        active: root.popoutVisible
        size: Math.max(22, Math.round(40 * root.unit))
        glyph: WeatherStatus.condition.glyph
        fallback: WeatherStatus.condition.icon
        glyphSize: root.panelIconSize
        text: [root.showTemperature ? WeatherStatus.temperatureText : "",
               root.showPlace ? WeatherStatus.placeName : ""].filter(s => s).join(" ")
    }

    popoutWidth: 320
    popout: Component {
        Item {
            implicitWidth: 320
            implicitHeight: body.implicitHeight

            Column {
                id: body
                width: parent.width
                spacing: 12

                Row {
                    width: parent.width
                    spacing: 12

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: WeatherStatus.condition.glyph
                        size: 42
                        color: Theme.acc
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 54

                        PanelText {
                            text: WeatherStatus.ready ? WeatherStatus.temperatureText : "--"
                            font.pixelSize: 26
                            font.weight: Font.Medium
                        }

                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: WeatherStatus.ready
                                ? [WeatherStatus.condition.label, WeatherStatus.placeName].filter(s => s).join(" · ")
                                : (WeatherStatus.error.length > 0 ? WeatherStatus.error : "Asking…")
                            font.pixelSize: 12
                            color: Theme.mut
                        }
                    }
                }

                Row {
                    visible: WeatherStatus.ready
                    width: parent.width
                    spacing: 14

                    PanelText {
                        text: WeatherStatus.current
                            ? `Feels ${Forecast.degrees(WeatherStatus.current.feelsLike, WeatherStatus.temperatureUnit)}` : ""
                        font.pixelSize: 11
                        color: Theme.mut
                    }
                    PanelText {
                        text: WeatherStatus.current ? `Humidity ${Math.round(WeatherStatus.current.humidity)}%` : ""
                        font.pixelSize: 11
                        color: Theme.mut
                    }
                    PanelText {
                        text: WeatherStatus.current
                            ? `Wind ${Math.round(WeatherStatus.current.wind)} ${WeatherStatus.forecast?.windUnit ?? ""}` : ""
                        font.pixelSize: 11
                        color: Theme.mut
                    }
                }

                // The next hours, across, scrolled by dragging.
                Flickable {
                    visible: WeatherStatus.ready
                    width: parent.width
                    height: 72
                    contentWidth: hours.implicitWidth
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                        id: hours
                        spacing: 2

                        Repeater {
                            model: WeatherStatus.hours.slice(0, 12)

                            Column {
                                id: hour
                                required property var modelData
                                width: 48
                                spacing: 3

                                PanelText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Qt.formatDateTime(new Date(hour.modelData.when), "HH")
                                    font.pixelSize: 11
                                    color: Theme.mut
                                }

                                Glyph {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: Forecast.describe(hour.modelData.code, hour.modelData.isDay).glyph
                                    size: 18
                                    color: Theme.acc
                                }

                                PanelText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Forecast.degrees(hour.modelData.temperature, "°")
                                    font.pixelSize: 12
                                }

                                PanelText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: hour.modelData.rain > 0
                                    text: `${Math.round(hour.modelData.rain)}%`
                                    font.pixelSize: 10
                                    color: Theme.mut
                                }
                            }
                        }
                    }
                }

                Column {
                    visible: WeatherStatus.ready
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: WeatherStatus.days.slice(0, Math.max(1, root.days))

                        Item {
                            id: line
                            required property var modelData
                            width: parent.width
                            height: 20

                            PanelText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 64
                                text: Forecast.dayName(line.modelData.when, Date.now(), Qt.locale())
                                font.pixelSize: 12
                                color: Theme.mut
                            }

                            Glyph {
                                x: 68
                                anchors.verticalCenter: parent.verticalCenter
                                name: Forecast.describe(line.modelData.code, true).glyph
                                size: 16
                                color: Theme.acc
                            }

                            PanelText {
                                x: 94
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

                Item {
                    width: parent.width
                    height: 20

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: WeatherStatus.fetchedAt > 0
                            ? `Open-Meteo · ${Qt.formatDateTime(new Date(WeatherStatus.fetchedAt), "HH:mm")}`
                            : "Open-Meteo"
                        font.pixelSize: 10
                        color: Theme.mut
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        size: 24
                        glyph: "refresh"
                        iconName: "view-refresh"
                        color: Theme.mut
                        onActivated: WeatherStatus.refresh(true)
                    }
                }
            }
        }
    }
}
