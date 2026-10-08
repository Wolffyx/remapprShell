pragma ComponentBehavior: Bound

// The sidebar: what is playing, the day, the weather, the machine, and the
// latest notifications, down one edge of the screen.
//
// A layer surface that keeps clear of the panel, whichever edge that is on,
// and above everything else -- a full-screen window included, since it is
// only ever up because it was asked for. It asks for the keyboard only when
// clicked, and Escape or the close button puts it away; the machine's numbers
// are read only while it is open.
//
// Which edge is `sidebar.position`, and the whole surface follows it -- the
// anchor, the margin, and the direction it slides in from. It slides the whole
// way, from the edge itself: the surface runs to the edge and only the card
// takes the pointer, so the margin between the card and the edge stays the
// window's under it -- a scrollbar there works with the sidebar up. It
// reserves no space by default: an exclusive zone moves every maximised window
// aside for as long as the sidebar is up, which reads as the desktop changing
// shape rather than as a panel sliding over it. `sidebar.reserveSpace` is
// there for people who want the other behaviour.
//
// How far out it is follows a pull from its edge while the pointer is down
// (Surfaces.sidebarPull, SidebarHandle), and animates the rest of the time --
// out when it opens, back to its edge when it closes, after which it tells
// Surfaces it is gone. Opened by the pointer pushed into its edge, it goes
// away again once the pointer has left it (`sidebar.closeOnLeave`).
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
import qs.core
import qs.domain.config
import qs.domain.sidebar.cards
import qs.domain.sidebar.gesture
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
    readonly property int cardWidth: Math.max(280, Number(ConfigStore.value("sidebar.width", 396)))
    readonly property var cards: Cards.order(ConfigStore.value("sidebar.cards", []))

    // How far the card moves to be all the way out: its width and the margin
    // between it and the edge.
    readonly property int travel: win.cardWidth + win.margin

    // Opened by the pointer pushed into the edge, which happens on the way to
    // something else often enough that a sidebar which stayed would be in the
    // way. Opened any other way, it was asked for, and stays.
    readonly property bool closesOnLeave: Surfaces.sidebarOpenedBy === "edge"
        && ConfigStore.value("sidebar.closeOnLeave", true) === true

    // What draws each card, by its id.
    readonly property var cardFor: ({
        media: media,
        day: day,
        weather: weather,
        machine: machine,
        notifications: notes
    })

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

    // Normal, with no zone of its own: clear of the panel, nothing moved
    // aside. Auto reserves exactly its width on that side, which is what
    // `sidebar.reserveSpace` asks for -- Normal was that choice once, and
    // with no zone set it reserved nothing: the setting did nothing.
    exclusionMode: win.reserves ? ExclusionMode.Auto : ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: `${Branding.slug}-sidebar`
    color: "transparent"
    implicitWidth: win.travel

    // Only the card takes the pointer; see the note at the top.
    mask: Region { item: card }

    BackgroundEffect.blurRegion: Theme.translucent ? win._card : null
    readonly property Region _card: Region { item: card; radius: card.radius }

    Component.onCompleted: {
        SystemStats.watch(true);
        WeatherStatus.refresh(false);
        win.settle();
        win.awaitPointer();
    }
    Component.onDestruction: SystemStats.watch(false)

    readonly property SystemClock clock: SystemClock { precision: SystemClock.Minutes }

    // How far out it is, 0 to 1.
    property real shown: 0

    // Under the pointer while a pull holds it; otherwise on its way out, or
    // back to its edge.
    function settle() {
        slide.stop();
        // Gone already, and about to be taken down with it.
        if (!Surfaces.sidebar)
            return;
        if (Surfaces.sidebarPull >= 0) {
            win.shown = Surfaces.sidebarPull;
            return;
        }
        const to = Surfaces.sidebarLeaving ? 0 : 1;
        const ms = Math.round(Theme.animationMs * 1.25 * Math.abs(to - win.shown));
        if (ms <= 0) {
            win.shown = to;
            win.landed();
            return;
        }
        slide.from = win.shown;
        slide.to = to;
        slide.duration = ms;
        slide.start();
    }

    function landed() {
        if (Surfaces.sidebarLeaving && win.shown <= 0)
            Surfaces.finishSidebar();
    }

    Connections {
        target: Surfaces

        function onSidebarChanged() { win.settle(); }
        function onSidebarPullChanged() { win.settle(); }
        function onSidebarLeavingChanged() { win.settle(); }
    }

    // Opened from the edge: the pointer has a moment to come to it.
    function awaitPointer() {
        if (!win.closesOnLeave || inside.hovered)
            return;
        away.interval = 1800;
        away.restart();
    }

    onClosesOnLeaveChanged: win.awaitPointer()

    NumberAnimation {
        id: slide
        target: win
        property: "shown"
        easing.type: Easing.OutCubic
        onFinished: win.landed()
    }

    // Away once the pointer has been in and left, or if it never comes.
    Timer {
        id: away
        onTriggered: {
            if (win.closesOnLeave && !inside.hovered)
                Surfaces.closeSidebar();
        }
    }

    Rectangle {
        id: card

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: win.cardWidth
        // Its place against the edge, moved towards it by however much is
        // not out yet -- by `x` rather than a transform, so the regions that
        // take the pointer and blur behind it move with it.
        x: (win.leftEdge ? win.margin : 0) + Gesture.offset(win.shown, win.travel, win.leftEdge)
        radius: Theme.radius
        color: Theme.glass
        border.width: 1
        border.color: Theme.out
        opacity: 0.4 + 0.6 * win.shown

        focus: true
        Keys.onEscapePressed: Surfaces.closeSidebar()

        HoverHandler {
            id: inside

            onHoveredChanged: {
                if (inside.hovered) {
                    away.stop();
                    return;
                }
                if (!win.closesOnLeave)
                    return;
                away.interval = 450;
                away.restart();
            }
        }

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
                        onActivated: Surfaces.closeSidebar()
                    }
                }

                Repeater {
                    model: win.cards

                    Loader {
                        required property var modelData
                        width: body.width
                        sourceComponent: win.cardFor[modelData.id] ?? null
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
