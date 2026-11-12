pragma ComponentBehavior: Bound

// Launchpad: every application, over the whole screen, a page at a time --
// the start menu when `launcher.layout` is "launchpad", as macOS has it.
//
// The applications are A to Z, in pages sized to the screen
// (Apps.launchpadGrid); typing filters them the way the launcher scores
// (Apps.search), and the search field keeps the keyboard the whole time.
// Keys: arrows move the selection, PageUp/PageDown and the wheel turn the
// page, Return starts the selected application, Escape clears what was typed
// and then closes. A click on the dimmed screen closes it too. Starting an
// application goes through the built-in provider, so it counts towards what
// the launcher offers first, as every other way in does.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.domain.config
import qs.domain.launcher
import qs.domain.launcher.apps
import qs.domain.theme
import qs.ui.primitives

PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    readonly property var provider: LauncherService.builtin

    // How much of the screen behind shows through: the backdrop is the
    // theme's own surface at this opacity, blurred where the compositor
    // blurs (`launcher.launchpadBackdrop`, percent).
    readonly property real backdrop: Math.max(0, Math.min(100, Number(ConfigStore.value("launcher.launchpadBackdrop", 85)) || 0)) / 100

    property string query: ""
    property int page: 0
    property int selected: 0

    readonly property var grid: Apps.launchpadGrid(win.width, win.height)
    readonly property int perPage: win.grid.columns * win.grid.rows
    readonly property var found: Apps.search(win.provider.applications, win.query, [])
    readonly property var pages: Apps.pages(win.found, win.perPage)
    readonly property int pageCount: win.pages.length

    onQueryChanged: {
        win.page = 0;
        win.selected = 0;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    // Top, as the search is: never over a full-screen window.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    BackgroundEffect.blurRegion: Theme.translucent ? win._blur : null
    readonly property Region _blur: Region { item: scrim }

    property real shown
    NumberAnimation on shown { from: 0; to: 1; duration: Theme.animationMs; easing.type: Easing.OutCubic }

    Component.onCompleted: Qt.callLater(() => field.forceActiveFocus())

    function turn(step) {
        win.page = Math.max(0, Math.min(win.pageCount - 1, win.page + step));
        win.selected = win.page * win.perPage;
    }

    // The selection moves within everything found; the page follows it.
    function move(step) {
        if (win.found.length === 0)
            return;
        win.selected = Math.max(0, Math.min(win.found.length - 1, win.selected + step));
        win.page = Math.floor(win.selected / win.perPage);
    }

    function launch(app) {
        if (!app)
            return;
        win.provider.launch(app);
        win.provider.close();
    }

    function back() {
        if (win.query.length > 0) {
            win.query = "";
            return;
        }
        win.provider.close();
    }

    readonly property var _keys: ({
        [Qt.Key_Left]: () => win.move(-1),
        [Qt.Key_Right]: () => win.move(1),
        [Qt.Key_Up]: () => win.move(-win.grid.columns),
        [Qt.Key_Down]: () => win.move(win.grid.columns),
        [Qt.Key_PageUp]: () => win.turn(-1),
        [Qt.Key_PageDown]: () => win.turn(1),
        [Qt.Key_Return]: () => win.launch(win.found[win.selected]),
        [Qt.Key_Enter]: () => win.launch(win.found[win.selected]),
        [Qt.Key_Escape]: () => win.back()
    })

    function handleKey(event) {
        const act = win._keys[event.key];
        if (!act)
            return;
        act();
        event.accepted = true;
    }

    // The screen behind, covered by the theme's surface and blurred; a click
    // on it closes, the wheel turns the page.
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Theme.alpha(Theme.s1, win.backdrop)
        opacity: win.shown

        MouseArea {
            anchors.fill: parent
            onPressed: win.provider.close()
            onWheel: wheel => win.turn(wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0 ? -1 : 1)
        }
    }

    // The search field, at the top.
    Rectangle {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        y: 56
        width: Math.min(360, win.width - 64)
        height: 40
        radius: height / 2
        color: Theme.glass
        border.width: 1
        border.color: Theme.out
        opacity: win.shown

        Glyph {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            fallback: "search"
            size: 18
            color: Theme.mut
        }

        TextInput {
            id: field
            x: 42
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 56
            color: Theme.fg
            font.pixelSize: 15
            font.family: Theme.fontFamily
            clip: true
            text: win.query
            onTextEdited: win.query = text
            Keys.onPressed: event => win.handleKey(event)
        }

        PanelText {
            x: 42
            anchors.verticalCenter: parent.verticalCenter
            visible: field.text.length === 0
            text: "Search"
            color: Theme.mut
            font.pixelSize: 15
        }
    }

    // The page.
    Grid {
        id: tiles
        anchors.horizontalCenter: parent.horizontalCenter
        y: box.y + box.height + Math.max(32, (win.height - box.y - box.height - 80 - win.grid.rows * 150) / 2)
        columns: win.grid.columns
        columnSpacing: 0
        rowSpacing: 0
        opacity: win.shown

        Repeater {
            model: win.pages[win.page] ?? []

            Item {
                id: tile

                required property var modelData
                required property int index
                readonly property bool current: win.page * win.perPage + tile.index === win.selected

                width: 140
                height: 150

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: Theme.radiusOf(18)
                    color: tile.current ? Theme.hover : (hover.hovered ? Theme.alpha(Theme.fg, 0.05) : "transparent")
                    border.width: tile.current ? 1 : 0
                    border.color: Theme.out
                }

                PanelIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18
                    implicitSize: 72
                    iconName: tile.modelData.icon ?? ""
                }

                PanelText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 102
                    width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tile.modelData.name ?? ""
                    color: Theme.fg
                    font.pixelSize: 13
                }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: win.launch(tile.modelData) }
            }
        }
    }

    PanelText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: tiles.y + 40
        visible: win.found.length === 0
        text: "Nothing matches"
        color: Theme.mut
        font.pixelSize: 15
    }

    // A dot a page; the one showing filled. Clicking one turns to it.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        spacing: 10
        visible: win.pageCount > 1
        opacity: win.shown

        Repeater {
            model: win.pageCount

            Rectangle {
                id: dot
                required property int index
                width: 8
                height: 8
                radius: 4
                color: dot.index === win.page ? Theme.fg : Theme.alpha(Theme.fg, 0.3)

                TapHandler {
                    onTapped: {
                        win.page = dot.index;
                        win.selected = dot.index * win.perPage;
                    }
                }
            }
        }
    }
}
