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
//
// The cards are files of their own -- SidebarCard is the frame, and
// SidebarMediaCard, SidebarDayCard, SidebarWeatherCard, SidebarMachineCard and
// SidebarNotesCard fill it -- and this file is the surface they sit in.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.domain.config
import qs.domain.sidebar.cards
import qs.domain.surfaces
import qs.domain.system
import qs.domain.theme
import qs.domain.weather
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

    readonly property SystemClock clock: SystemClock { precision: SystemClock.Minutes }

    property real shown: 0
    NumberAnimation on shown { from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic; running: true }

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
    //
    // Each is a file of its own, drawn in a SidebarCard. What they share with
    // the sidebar is handed to them here: whether they are open, which is a
    // setting the sidebar keeps, and the clock the day, the forecast and the
    // notifications all read.

    Component {
        id: media

        SidebarMediaCard {
            expanded: win.isOpen("media")
            onFold: win.fold("media")
        }
    }

    Component {
        id: day

        SidebarDayCard {
            expanded: win.isOpen("day")
            onFold: win.fold("day")
            clock: win.clock
        }
    }

    Component {
        id: weather

        SidebarWeatherCard {
            expanded: win.isOpen("weather")
            onFold: win.fold("weather")
            clock: win.clock
        }
    }

    Component {
        id: machine

        SidebarMachineCard {
            expanded: win.isOpen("machine")
            onFold: win.fold("machine")
        }
    }

    Component {
        id: notes

        SidebarNotesCard {
            expanded: win.isOpen("notifications")
            onFold: win.fold("notifications")
            clock: win.clock
        }
    }
}
