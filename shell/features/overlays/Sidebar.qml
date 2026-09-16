pragma ComponentBehavior: Bound

// The sidebar: what is playing, the day, the weather, the machine, and the
// latest notifications, down one edge of the screen.
//
// A layer surface that keeps to the usable area, so it sits clear of the panel
// whichever edge that is on. It asks for the keyboard only when clicked, and
// Escape or the close button puts it away; the machine's numbers are read only
// while it is open.
//
// Which edge is `sidebar.position`, and the whole surface follows it -- the
// anchor, the margin, and the direction it slides in from. It reserves no
// space by default: an exclusive zone moves every maximised window aside for
// as long as the sidebar is up, which reads as the desktop changing shape
// rather than as a panel sliding over it. `sidebar.reserveSpace` is there for
// people who want the other behaviour.
//
// Every card folds. Which are open is a setting (Cards, and `sidebar.expanded`)
// rather than a property here, so a sidebar opened tomorrow looks the way this
// one was left.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.domain.config
import qs.domain.notifications
import qs.domain.notifications.centre
import qs.domain.session
import qs.domain.sidebar.cards
import qs.domain.status
import qs.domain.status.icons
import qs.domain.surfaces
import qs.domain.system
import qs.domain.system.stats
import qs.domain.theme
import qs.domain.weather
import qs.domain.weather.forecast
import qs.ui.primitives
import qs.ui.controls

PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    readonly property bool leftEdge: Cards.onLeft(ConfigStore.value("sidebar.position", "right"))
    readonly property int margin: Math.max(0, Number(ConfigStore.value("sidebar.margin", 16)))
    readonly property bool reserves: ConfigStore.value("sidebar.reserveSpace", false) === true
    readonly property var cards: Cards.order(ConfigStore.value("sidebar.cards", []))
    readonly property var expanded: ConfigStore.value("sidebar.expanded", [])

    function isOpen(id) { return Cards.isOpen(win.expanded, id); }
    function fold(id) { ConfigStore.set("sidebar.expanded", Cards.toggled(win.expanded, id)); }

    anchors {
        top: true
        bottom: true
        left: win.leftEdge
        right: !win.leftEdge
    }
    margins.top: win.margin
    margins.bottom: win.margin
    margins.left: win.margin
    margins.right: win.margin

    // Ignore rather than Normal: see the note at the top. A sidebar that
    // pushes the desktop aside is a choice, and it is off.
    exclusionMode: win.reserves ? ExclusionMode.Normal : ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"
    implicitWidth: Math.max(280, Number(ConfigStore.value("sidebar.width", 396)))

    BackgroundEffect.blurRegion: Theme.translucent ? win._card : null
    readonly property Region _card: Region { item: card; radius: card.radius }

    Component.onCompleted: {
        SystemStats.watch(true);
        WeatherStatus.refresh(false);
    }
    Component.onDestruction: SystemStats.watch(false)

    readonly property var player: MediaStatus.current
    readonly property SystemClock clock: SystemClock { precision: SystemClock.Minutes }

    property real shown: 0
    NumberAnimation on shown { from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic; running: true }

    // One card: a heading that folds it, the part always shown, and the part
    // that appears when it is open.
    component Card: Rectangle {
        id: box

        required property string cardId
        required property string title
        required property string glyph
        property bool foldable: true
        property alias content: inner.data
        default property alias extra: more.data

        readonly property bool open: box.foldable ? win.isOpen(box.cardId) : true

        width: parent ? parent.width : 0
        height: shape.implicitHeight + 32
        radius: 20
        color: Theme.s2

        Column {
            id: shape
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 12

            Item {
                width: parent.width
                height: 20

                Glyph {
                    id: mark
                    anchors.verticalCenter: parent.verticalCenter
                    name: box.glyph
                    size: 16
                    color: Theme.mut
                }

                PanelText {
                    anchors.left: mark.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: box.title.toUpperCase()
                    font.pixelSize: 11
                    font.letterSpacing: 0.8
                    font.weight: Font.Medium
                    color: Theme.mut
                }

                Glyph {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: box.foldable
                    name: box.open ? "expand_less" : "expand_more"
                    size: 18
                    color: Theme.mut
                }

                HoverHandler { cursorShape: box.foldable ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler {
                    enabled: box.foldable
                    onTapped: win.fold(box.cardId)
                }
            }

            Column {
                id: inner
                width: parent.width
                spacing: 12
            }

            // Built only while it is open, and destroyed when it folds: the
            // month grid and the forecast are not worth keeping alive behind
            // a closed card.
            Column {
                id: more
                width: parent.width
                spacing: 12
                visible: box.open
                height: box.open ? implicitHeight : 0
                clip: true
                Behavior on height { NumberAnimation { duration: Theme.animationMs; easing.type: Easing.OutCubic } }
            }
        }
    }

    component Meter: Column {
        id: meter
        property string label: ""
        property string value: ""
        property real fraction: 0
        width: parent ? parent.width : 0
        spacing: 6

        Item {
            width: parent.width
            height: 16
            PanelText { text: meter.label; font.pixelSize: 12; color: Theme.mut }
            PanelText { anchors.right: parent.right; text: meter.value; font.pixelSize: 12; color: Theme.mut }
        }

        Rectangle {
            width: parent.width
            height: 5
            radius: 2.5
            color: Theme.alpha(Theme.fg, 0.12)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, meter.fraction))
                height: parent.height
                radius: parent.radius
                color: Theme.acc
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }
    }

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

    Rectangle {
        id: card

        anchors.fill: parent
        radius: Theme.radius
        color: Theme.glass
        border.width: 1
        border.color: Theme.out
        opacity: win.shown

        // In from the edge it lives on.
        transform: Translate { x: (1 - win.shown) * (win.leftEdge ? -24 : 24) }

        focus: true
        Keys.onEscapePressed: Surfaces.closeAll()

        Flickable {
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width
                spacing: 14

                Item {
                    width: parent.width
                    height: 34

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Sidebar"
                        font.pixelSize: 18
                        font.weight: Font.Medium
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "close"
                        iconName: "window-close"
                        color: Theme.mut
                        onActivated: Surfaces.closeAll()
                    }
                }

                Repeater {
                    model: win.cards

                    Loader {
                        required property var modelData
                        width: body.width
                        sourceComponent: modelData.id === "media" ? media
                                       : modelData.id === "day" ? day
                                       : modelData.id === "weather" ? weather
                                       : modelData.id === "machine" ? machine
                                       : modelData.id === "notifications" ? notes
                                       : null
                    }
                }
            }
        }
    }

    // ---- the cards ---------------------------------------------------------

    // What is playing. Folded, it is the track; open, the controls and how far
    // through it is.
    Component {
        id: media

        Card {
            cardId: "media"
            title: "Playing"
            glyph: "music_note"

            content: [
                Row {
                    width: parent.width
                    spacing: 14

                    Rectangle {
                        width: 56
                        height: 56
                        radius: 14
                        color: Theme.accC
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: win.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        Glyph {
                            anchors.centerIn: parent
                            visible: !(win.player?.trackArtUrl)
                            name: "music_note"
                            size: 26
                            color: Theme.accCFg
                        }
                    }

                    Column {
                        width: parent.width - 70
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: MediaStatus.present ? MediaStatus.title : "Nothing playing"
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: MediaStatus.present ? Theme.fg : Theme.mut
                        }

                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            visible: text.length > 0
                            text: [MediaStatus.artist, win.player?.trackAlbum ?? ""].filter(s => s).join(" · ")
                            font.pixelSize: 13
                            color: Theme.mut
                        }
                    }
                }
            ]

            Item {
                visible: (win.player?.lengthSupported ?? false) && (win.player?.length ?? 0) > 0
                width: parent.width
                height: 30

                Rectangle {
                    id: track
                    y: 6
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.alpha(Theme.fg, 0.12)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, (win.player?.position ?? 0) / Math.max(1, win.player?.length ?? 1)))
                        height: parent.height
                        radius: parent.radius
                        color: Theme.acc
                    }

                    TapHandler {
                        onTapped: point => MediaStatus.seek((win.player?.length ?? 0) * point.position.x / track.width)
                    }
                }

                PanelText {
                    y: 14
                    text: StatusIcons.trackTime(win.player?.position ?? 0)
                    font.family: Theme.monoFamily
                    font.pixelSize: 11
                    color: Theme.mut
                }

                PanelText {
                    y: 14
                    anchors.right: parent.right
                    text: StatusIcons.trackTime(win.player?.length ?? 0)
                    font.family: Theme.monoFamily
                    font.pixelSize: 11
                    color: Theme.mut
                }
            }

            Row {
                visible: MediaStatus.present
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: win.player?.shuffleSupported ?? false
                    glyph: "shuffle"
                    color: (win.player?.shuffle ?? false) ? Theme.acc : Theme.fg
                    onActivated: win.player.shuffle = !win.player.shuffle
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "skip_previous"
                    onActivated: MediaStatus.previous()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 48
                    glyph: MediaStatus.playing ? "pause_circle" : "play_circle"
                    color: Theme.acc
                    onActivated: MediaStatus.toggle()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "skip_next"
                    onActivated: MediaStatus.next()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: win.player?.loopSupported ?? false
                    glyph: (win.player?.loopState ?? MprisLoopState.None) === MprisLoopState.Track ? "repeat_one" : "repeat"
                    color: (win.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None ? Theme.acc : Theme.fg
                    onActivated: {
                        const s = win.player.loopState;
                        win.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
                                             : s === MprisLoopState.Playlist ? MprisLoopState.Track
                                             : MprisLoopState.None;
                    }
                }
            }
        }
    }

    // The day. Folded, the date and how long the machine has been up; open,
    // the month -- with the forecast on the days it is known for.
    Component {
        id: day

        Card {
            id: dayCard
            cardId: "day"
            title: "Today"
            glyph: "calendar_month"

            readonly property var chosen: Forecast.dayAt(WeatherStatus.days, dayCard.picked.getTime())
            property date picked: win.clock.date

            content: [
                Row {
                    width: parent.width
                    spacing: 16

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        PanelText {
                            text: win.clock.date.toLocaleDateString(Qt.locale(), "dddd")
                            font.pixelSize: 20
                            font.weight: Font.Medium
                        }

                        PanelText {
                            // The weekday is the line above.
                            text: [win.clock.date.toLocaleDateString(Qt.locale(), "d MMMM yyyy"), Session.uptime].filter(s => s).join(" · ")
                            font.pixelSize: 12
                            color: Theme.mut
                        }
                    }
                }
            ]

            MonthGrid {
                id: month
                width: parent.width
                now: win.clock.date
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

    // The weather. Folded, now; open, the next hours and the next days.
    Component {
        id: weather

        Card {
            cardId: "weather"
            title: "Weather"
            glyph: WeatherStatus.condition.glyph

            content: [
                // Off, or not yet answered: one line that says which, rather
                // than an empty card that looks broken.
                PanelText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: !WeatherStatus.ready
                    text: !WeatherStatus.enabled
                        ? "Off. Settings → Weather turns it on; it asks Open-Meteo for a forecast and nothing else."
                        : (WeatherStatus.error.length > 0 ? WeatherStatus.error : "Asking…")
                    font.pixelSize: 12
                    color: Theme.mut
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
                            text: Forecast.dayName(line.modelData.when, win.clock.date.getTime(), Qt.locale())
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

    // The machine. Folded, the processor and the memory; open, the rest.
    Component {
        id: machine

        Card {
            cardId: "machine"
            title: "Machine"
            glyph: "memory"

            content: [
                Meter {
                    label: SystemStats.cpuTemp > 0 ? `CPU · ${SystemStats.cpuTemp} °C` : "CPU"
                    value: `${Math.round(SystemStats.cpu * 100)}%`
                    fraction: SystemStats.cpu
                },
                Meter {
                    label: "Memory"
                    value: `${Stats.bytes(SystemStats.memUsed)} / ${Stats.bytes(SystemStats.memTotal)}`
                    fraction: SystemStats.memTotal > 0 ? SystemStats.memUsed / SystemStats.memTotal : 0
                }
            ]

            Meter {
                visible: SystemStats.gpu >= 0
                label: SystemStats.gpuTemp > 0 ? `GPU · ${SystemStats.gpuTemp} °C` : "GPU"
                value: `${Math.round(Math.max(0, SystemStats.gpu) * 100)}%`
                fraction: Math.max(0, SystemStats.gpu)
            }

            Meter {
                label: "Network"
                value: `${Stats.bytes(SystemStats.netRate)}/s`
                // A gigabit's worth is the whole bar.
                fraction: SystemStats.netRate / (125 * 1024 * 1024)
            }

            PanelText {
                width: parent.width
                text: Session.uptime.length > 0 ? `Up ${Session.uptime}` : ""
                font.pixelSize: 11
                color: Theme.mut
            }
        }
    }

    // The latest notifications, from the history. Folded, three; open, ten --
    // and a click opens whatever the notification was about.
    Component {
        id: notes

        Card {
            id: noteCard
            cardId: "notifications"
            title: "Notifications"
            glyph: "notifications"

            readonly property int shown: noteCard.open ? 10 : 3

            content: [
                PanelText {
                    width: parent.width
                    visible: !NotificationWatch.enabled || NotificationWatch.entries.length === 0
                    wrapMode: Text.WordWrap
                    text: NotificationWatch.enabled ? "Nothing recent."
                        : "The history is off; Settings → Notifications keeps one."
                    font.pixelSize: 12
                    color: Theme.mut
                },

                Repeater {
                    model: NotificationWatch.entries.slice(0, noteCard.shown)

                    Column {
                        id: note
                        required property var modelData
                        width: parent.width
                        spacing: 2

                        Item {
                            width: parent.width
                            height: 18

                            PanelText {
                                width: parent.width - when.width - 8
                                elide: Text.ElideRight
                                text: note.modelData.summary
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            PanelText {
                                id: when
                                anchors.right: parent.right
                                text: Centre.ago(note.modelData.when, win.clock.date.getTime())
                                font.family: Theme.monoFamily
                                font.pixelSize: 11
                                color: Theme.mut
                            }
                        }

                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: note.modelData.appName
                            font.pixelSize: 12
                            color: Theme.mut
                        }

                        HoverHandler { cursorShape: NotificationWatch.openable(note.modelData) ? Qt.PointingHandCursor : Qt.ArrowCursor }
                        TapHandler {
                            enabled: NotificationWatch.openable(note.modelData)
                            onTapped: {
                                NotificationWatch.open(note.modelData);
                                Surfaces.closeAll();
                            }
                        }
                    }
                }
            ]

            TextButton {
                visible: NotificationWatch.entries.length > 0
                glyph: "clear_all"
                iconName: "edit-clear-history"
                text: "Clear"
                onActivated: NotificationWatch.clear()
            }
        }
    }
}
