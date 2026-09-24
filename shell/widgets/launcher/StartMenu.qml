pragma ComponentBehavior: Bound

// The built-in start menu, in the three layouts the design has:
//
//   twopane  categories down a rail; pinned apps and recent files; and
//            beside them you, what is playing, the machine, and the session
//   grid     pinned apps and recent files
//   list     every application, A to Z, with an index down the side
//
// Typing anywhere searches, as the search field says; with the action prefix
// it offers the shell's actions too. The arranging is Apps' and the choosing
// the provider's -- this only draws.

import QtQuick
import QtQuick.Controls
import qs.domain.launcher
import qs.domain.launcher.apps
import qs.domain.launcher.providers
import qs.domain.session
import qs.domain.status
import qs.domain.system
import qs.domain.system.stats
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Item {
    id: menu

    required property BuiltinProvider provider
    readonly property string layout: menu.provider.layout

    // Which part of the menu is showing: "home" (pinned and recent), a rail
    // category, "everything", or "recent".
    property string view: "home"
    readonly property bool searching: menu.provider.query.length > 0

    implicitWidth: menu.layout === "twopane" ? 928 : menu.layout === "grid" ? 496 : 420
    implicitHeight: menu.layout === "twopane" ? 668 : menu.layout === "grid" ? 540 : 600

    focus: true
    Keys.forwardTo: [search]

    // The machine's numbers are read only while the two-pane menu, which
    // shows them, is open.
    readonly property bool twopane: menu.layout === "twopane"
    property bool watching: false

    function watchStats(on) {
        if (on !== menu.watching) {
            menu.watching = on;
            SystemStats.watch(on);
        }
    }

    onTwopaneChanged: menu.watchStats(menu.twopane)
    Component.onDestruction: menu.watchStats(false)
    Component.onCompleted: {
        menu.watchStats(menu.twopane);
        Qt.callLater(() => search.forceActiveFocus());
    }

    // ---- shared parts ------------------------------------------------------

    // The field: a real one, typed into from anywhere in the menu.
    component SearchField: Rectangle {
        property string placeholder: "Search apps, files and actions"
        height: 48
        radius: Theme.radiusOf(16)
        // An outline rather than a fill: a field drawn a shade lighter than
        // the menu it sits in is one more background to read past, and the
        // border says "type here" on its own.
        color: "transparent"
        border.width: 1
        border.color: search.activeFocus ? Theme.acc : Theme.out

        Glyph {
            id: lens
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 20
            color: Theme.mut
        }

        Rectangle {
            id: badge
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: badgeText.implicitWidth + 14
            height: 22
            radius: Theme.radiusOf(6)
            color: Theme.s1

            PanelText {
                id: badgeText
                anchors.centerIn: parent
                text: `${menu.provider.prefix} actions`
                font.family: Theme.monoFamily
                font.pixelSize: 11
                color: Theme.mut
            }
        }

        // Reparented into whichever layout is showing.
        Item {
            id: fieldSlot
            anchors.left: lens.right
            anchors.leftMargin: 10
            anchors.right: badge.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 30
            Component.onCompleted: search.parent = fieldSlot
        }

        PanelText {
            anchors.left: lens.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: search.text.length === 0
            text: parent.placeholder
            font.pixelSize: 15
            color: Theme.mut
        }
    }

    TextField {
        id: search
        anchors.fill: parent
        focus: true
        color: Theme.fg
        selectionColor: Theme.accC
        selectedTextColor: Theme.accCFg
        font.family: Theme.fontFamily
        font.pixelSize: 15
        background: null
        leftPadding: 2
        text: menu.provider.query

        onTextChanged: {
            menu.provider.query = text;
            menu.provider.selectedIndex = 0;
        }

        Keys.onDownPressed: menu.provider.moveSelection(1)
        Keys.onUpPressed: menu.provider.moveSelection(-1)
        Keys.onReturnPressed: menu.provider.activateSelected()
        Keys.onEnterPressed: menu.provider.activateSelected()
        Keys.onEscapePressed: {
            if (text.length > 0)
                text = "";
            else
                menu.provider.close();
        }
    }

    // An application as a tile: its icon on a tinted square, its name under.
    component AppTile: Item {
        id: tile

        required property var modelData
        property bool framed: true

        width: 96
        height: 100

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusOf(16)
            color: tileHover.hovered ? Theme.s2 : "transparent"
        }

        Rectangle {
            id: square
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            width: 52
            height: 52
            radius: Theme.radiusOf(16)
            color: tile.framed ? Theme.accC : "transparent"

            PanelIcon {
                anchors.centerIn: parent
                implicitSize: tile.framed ? 30 : 40
                iconName: tile.modelData.icon ?? ""
            }
        }

        PanelText {
            anchors.top: square.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tile.modelData.name
            font.pixelSize: 12
        }

        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: menu.provider.launch(tile.modelData) }
    }

    // A search result: an application, an action or a sum.
    component ResultRow: Rectangle {
        id: result

        required property var modelData
        required property int index
        readonly property bool selected: result.index === menu.provider.selectedIndex

        width: parent ? parent.width : 0
        height: 52
        radius: Theme.radiusOf(14)
        color: result.selected ? Theme.accC : (resultHover.hovered ? Theme.s2 : "transparent")

        Item {
            id: resultIcon
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26

            PanelIcon {
                anchors.fill: parent
                visible: result.modelData.kind === "app"
                iconName: result.modelData.icon ?? ""
            }

            Glyph {
                anchors.centerIn: parent
                visible: result.modelData.kind !== "app"
                name: result.modelData.glyph ?? ""
                size: 22
                color: result.selected ? Theme.acc : Theme.mut
            }
        }

        Column {
            anchors.left: resultIcon.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            PanelText {
                width: parent.width
                elide: Text.ElideRight
                text: result.modelData.name
                font.pixelSize: 14
                font.weight: Font.Medium
                color: result.selected ? Theme.accCFg : Theme.fg
            }

            PanelText {
                visible: text.length > 0
                width: parent.width
                elide: Text.ElideRight
                text: result.modelData.description ?? ""
                font.pixelSize: 12
                color: result.selected ? Theme.alpha(Theme.accCFg, 0.75) : Theme.mut
            }
        }

        HoverHandler {
            id: resultHover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: if (hovered) menu.provider.selectedIndex = result.index
        }
        TapHandler { onTapped: menu.provider.activate(result.modelData) }
    }

    component Results: Column {
        spacing: 2

        Repeater {
            model: menu.provider.results
            ResultRow {}
        }

        PanelText {
            visible: menu.provider.results.length === 0
            topPadding: 8
            leftPadding: 12
            text: "No matches"
            color: Theme.mut
        }
    }

    component RecentRow: Rectangle {
        id: recent

        required property var modelData

        width: parent ? parent.width : 0
        height: 40
        radius: Theme.radiusOf(14)
        color: recentHover.hovered ? Theme.s2 : "transparent"

        Glyph {
            id: recentGlyph
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            name: recent.modelData.folder ? "folder_open" : "description"
            size: 20
            color: Theme.mut
        }

        PanelText {
            anchors.left: recentGlyph.right
            anchors.leftMargin: 14
            anchors.right: recentDir.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: recent.modelData.name
            font.pixelSize: 14
        }

        PanelText {
            id: recentDir
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 200)
            elide: Text.ElideMiddle
            text: recent.modelData.dir
            font.family: Theme.monoFamily
            font.pixelSize: 12
            color: Theme.mut
        }

        HoverHandler { id: recentHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                RecentFiles.open(recent.modelData);
                menu.provider.close();
            }
        }
    }

    component Footer: Item {
        width: parent ? parent.width : 0
        height: 50

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.out
        }

        Avatar {
            id: footAvatar
            y: 14
            size: 34
            source: Session.avatar
            initial: Session.initial
        }

        PanelText {
            anchors.left: footAvatar.right
            anchors.leftMargin: 12
            anchors.verticalCenter: footAvatar.verticalCenter
            text: Session.displayName
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        IconButton {
            anchors.right: parent.right
            anchors.verticalCenter: footAvatar.verticalCenter
            glyph: "power_settings_new"
            iconName: "system-shutdown"
            onActivated: {
                Session.prompt("promptAll");
                menu.provider.close();
            }
        }
    }

    component Heading: Item {
        id: heading

        property string text: ""
        property string link: ""
        signal linked

        width: parent ? parent.width : 0
        height: 22

        SectionLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: heading.text
        }

        PanelText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: heading.link.length > 0
            text: heading.link
            font.pixelSize: 13
            color: Theme.acc

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: heading.linked() }
        }
    }

    // A button on the two-pane menu's rail: in the accent while its view is
    // the one showing. Choosing one clears the search, which would otherwise
    // be showing instead of the view chosen.
    component RailButton: Rectangle {
        id: railButton

        property string glyph: ""
        property bool current: false
        property real glyphSize: railButton.current ? 24 : 22
        signal chosen

        width: 48
        height: 48
        radius: Theme.radiusOf(16)
        color: railButton.current ? Theme.acc : railHover.hovered ? Theme.s3 : "transparent"

        Glyph {
            anchors.centerIn: parent
            name: railButton.glyph
            size: railButton.glyphSize
            color: railButton.current ? Theme.accFg : Theme.mut
        }

        HoverHandler { id: railHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                search.text = "";
                railButton.chosen();
            }
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: menu.layout === "grid" ? gridLayout : menu.layout === "list" ? listLayout : twoPaneLayout
    }

    // ---- two panes ---------------------------------------------------------

    Component {
        id: twoPaneLayout

        Item {
            // The rail.
            //
            // A column of buttons, not a panel of its own. It used to be
            // filled a shade lighter than the menu and rounded on its left,
            // which put a second background inside the popout's -- and, where
            // its corner radius did not land exactly on the card's, left the
            // menu's bottom-left corner looking square. One surface, a
            // hairline where one part ends and the next begins.
            Item {
                id: rail
                width: 78
                height: parent.height

                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: Theme.out
                }

                Column {
                    y: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Repeater {
                        model: Apps.categories

                        RailButton {
                            id: category
                            required property var modelData
                            glyph: category.modelData.glyph
                            current: (category.modelData.id === "all" && menu.view === "home")
                                     || menu.view === category.modelData.id
                            onChosen: menu.view = category.modelData.id === "all" ? "home" : category.modelData.id
                        }
                    }
                }

                // Recent files, at the foot of the rail. Its glyph stays the
                // one size, current or not, as it always has.
                RailButton {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    glyph: "history"
                    glyphSize: 22
                    current: menu.view === "recent"
                    onChosen: menu.view = "recent"
                }
            }

            // The middle.
            Column {
                id: middle
                x: rail.width + 24
                y: 22
                width: parent.width - rail.width - side.width - 48
                height: parent.height - 44
                spacing: 20

                SearchField { width: parent.width }

                Results {
                    visible: menu.searching
                    width: parent.width
                }

                Flickable {
                    visible: !menu.searching
                    width: parent.width
                    height: parent.height - 68
                    contentHeight: body.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: body
                        width: parent.width
                        spacing: 14

                        readonly property var shown: menu.view === "home" ? menu.provider.pinnedApps
                            : menu.view === "everything" ? Apps.inCategory(menu.provider.applications, "all")
                            : menu.view === "recent" ? []
                            : Apps.inCategory(menu.provider.applications, menu.view)

                        Heading {
                            visible: menu.view !== "recent"
                            text: menu.view === "home" ? "Pinned"
                                : menu.view === "everything" ? "All apps"
                                : (Apps.categories.find(c => c.id === menu.view)?.label ?? "")
                            link: menu.view === "home" ? "All apps" : "Back"
                            onLinked: menu.view = menu.view === "home" ? "everything" : "home"
                        }

                        Grid {
                            visible: menu.view !== "recent"
                            columns: 5
                            columnSpacing: (body.width - 5 * 96) / 4
                            rowSpacing: 4

                            Repeater {
                                model: body.shown
                                AppTile { framed: menu.view === "home" }
                            }
                        }

                        Heading {
                            visible: menu.view === "home" || menu.view === "recent"
                            text: "Recent"
                        }

                        Column {
                            visible: menu.view === "home" || menu.view === "recent"
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: menu.view === "recent" ? RecentFiles.files : RecentFiles.files.slice(0, 3)
                                RecentRow {}
                            }

                            PanelText {
                                visible: RecentFiles.files.length === 0
                                leftPadding: 12
                                text: "No recent files."
                                color: Theme.mut
                            }
                        }
                    }
                }
            }

            // The side: who, what is playing, the machine, the session.
            Item {
                id: side
                anchors.right: parent.right
                width: 276
                height: parent.height

                Rectangle {
                    width: 1
                    height: parent.height
                    color: Theme.out
                }

                Column {
                    x: 20
                    y: 22
                    width: parent.width - 40
                    spacing: 14

                    Item {
                        width: parent.width
                        height: 44

                        Avatar {
                            id: sideAvatar
                            size: 44
                            source: Session.avatar
                            initial: Session.initial
                        }

                        Column {
                            anchors.left: sideAvatar.right
                            anchors.leftMargin: 12
                            anchors.right: sidePower.left
                            anchors.verticalCenter: parent.verticalCenter

                            PanelText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: Session.displayName
                                font.pixelSize: 15
                                font.weight: Font.Medium
                            }

                            PanelText {
                                text: Session.uptime
                                font.family: Theme.monoFamily
                                font.pixelSize: 12
                                color: Theme.mut
                            }
                        }

                        IconButton {
                            id: sidePower
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            size: 36
                            glyph: "power_settings_new"
                            iconName: "system-shutdown"
                            onActivated: {
                                Session.prompt("promptAll");
                                menu.provider.close();
                            }
                        }
                    }

                    // What is playing. No card of its own: inside a popout
                    // that is already a card, a second one is just another
                    // background.
                    Item {
                        width: parent.width
                        height: player.implicitHeight + 28

                        Column {
                            id: player
                            x: 14
                            y: 14
                            width: parent.width - 28
                            spacing: 10

                            Row {
                                width: parent.width
                                spacing: 12

                                AlbumArt {
                                    width: 56
                                    height: 56
                                    source: MediaStatus.current?.trackArtUrl ?? ""
                                }

                                Column {
                                    width: parent.width - 68
                                    anchors.verticalCenter: parent.verticalCenter

                                    PanelText {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: MediaStatus.present ? MediaStatus.title : "Nothing playing"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: MediaStatus.present ? Theme.fg : Theme.mut
                                    }

                                    PanelText {
                                        visible: text.length > 0
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: MediaStatus.artist
                                        font.pixelSize: 12
                                        color: Theme.mut
                                    }
                                }
                            }

                            Row {
                                visible: MediaStatus.present
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 12

                                IconButton { glyph: "skip_previous"; onActivated: MediaStatus.previous() }
                                IconButton {
                                    size: 40
                                    glyph: MediaStatus.playing ? "pause_circle" : "play_circle"
                                    color: Theme.acc
                                    onActivated: MediaStatus.toggle()
                                }
                                IconButton { glyph: "skip_next"; onActivated: MediaStatus.next() }
                            }
                        }
                    }

                    // The machine.
                    Item {
                        width: parent.width
                        height: meters.implicitHeight + 32

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.out
                        }

                        Column {
                            id: meters
                            x: 16
                            y: 16
                            width: parent.width - 32
                            spacing: 13

                            Repeater {
                                model: [
                                    { label: SystemStats.cpuTemp > 0 ? `CPU · ${SystemStats.cpuTemp} °C` : "CPU",
                                      value: `${Math.round(SystemStats.cpu * 100)}%`, fraction: SystemStats.cpu, shown: true },
                                    { label: "Memory", value: `${Stats.bytes(SystemStats.memUsed)} / ${Stats.bytes(SystemStats.memTotal)}`,
                                      fraction: SystemStats.memTotal > 0 ? SystemStats.memUsed / SystemStats.memTotal : 0, shown: true },
                                    { label: "Storage", value: `${Stats.bytes(SystemStats.diskFree)} free`,
                                      fraction: SystemStats.diskSize > 0 ? 1 - SystemStats.diskFree / SystemStats.diskSize : 0, shown: SystemStats.diskSize > 0 },
                                    { label: SystemStats.gpuTemp > 0 ? `GPU · ${SystemStats.gpuTemp} °C` : "GPU",
                                      value: `${Math.round(Math.max(0, SystemStats.gpu) * 100)}%`, fraction: Math.max(0, SystemStats.gpu), shown: SystemStats.gpu >= 0 }
                                ].filter(m => m.shown)

                                Column {
                                    id: meter
                                    required property var modelData
                                    width: meters.width
                                    spacing: 6

                                    Item {
                                        width: parent.width
                                        height: 16
                                        PanelText { text: meter.modelData.label; font.pixelSize: 12; color: Theme.mut }
                                        PanelText { anchors.right: parent.right; text: meter.modelData.value; font.pixelSize: 12; color: Theme.mut }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 5
                                        radius: 2.5
                                        color: Theme.alpha(Theme.fg, 0.12)

                                        Rectangle {
                                            width: parent.width * Math.max(0, Math.min(1, meter.modelData.fraction))
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.acc
                                            Behavior on width { NumberAnimation { duration: 400 } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    x: 20
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 22
                    spacing: 8

                    Repeater {
                        model: [
                            { glyph: "lock", act: () => Session.lock() },
                            { glyph: "bedtime", act: () => Session.suspend() },
                            { glyph: "logout", act: () => Session.prompt("promptLogout") }
                        ]

                        Rectangle {
                            id: sessionButton
                            required property var modelData
                            width: (side.width - 40 - 16) / 3
                            height: 44
                            radius: Theme.radiusOf(14)
                            color: sessionHover.hovered ? Theme.s3 : Theme.s1

                            Glyph {
                                anchors.centerIn: parent
                                name: sessionButton.modelData.glyph
                                size: 20
                            }

                            HoverHandler { id: sessionHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    menu.provider.close();
                                    sessionButton.modelData.act();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- pinned grid -------------------------------------------------------

    Component {
        id: gridLayout

        Column {
            spacing: 18

            SearchField {
                width: parent.width
                placeholder: "Type to search"
            }

            Results {
                visible: menu.searching
                width: parent.width
                height: parent.height - 66 - 50
            }

            Column {
                visible: !menu.searching
                width: parent.width
                height: parent.height - 66 - 50
                spacing: 12

                Heading {
                    text: menu.view === "everything" ? "All apps" : "Pinned"
                    link: menu.view === "everything" ? "Back" : "All apps"
                    onLinked: menu.view = menu.view === "everything" ? "home" : "everything"
                }

                Flickable {
                    width: parent.width
                    height: menu.view === "everything" ? parent.height - 34 : pinnedGrid.implicitHeight
                    contentHeight: pinnedGrid.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Grid {
                        id: pinnedGrid
                        columns: 4
                        columnSpacing: (parent.width - 4 * 96) / 3
                        rowSpacing: 2

                        Repeater {
                            model: menu.view === "everything" ? Apps.inCategory(menu.provider.applications, "all")
                                                              : menu.provider.pinnedApps.slice(0, 12)
                            AppTile { framed: false }
                        }
                    }
                }

                Heading {
                    visible: menu.view !== "everything"
                    text: "Recommended"
                }

                Grid {
                    visible: menu.view !== "everything"
                    width: parent.width
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: RecentFiles.files.slice(0, 2)

                        Rectangle {
                            id: rec
                            required property var modelData
                            width: (parent.width - 8) / 2
                            height: 44
                            radius: Theme.radiusOf(14)
                            color: recHover.hovered ? Theme.s3 : Theme.s2

                            Glyph {
                                id: recGlyph
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                name: rec.modelData.folder ? "folder_open" : "description"
                                size: 20
                                color: Theme.mut
                            }

                            PanelText {
                                anchors.left: recGlyph.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: rec.modelData.name
                                font.pixelSize: 13
                            }

                            HoverHandler { id: recHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    RecentFiles.open(rec.modelData);
                                    menu.provider.close();
                                }
                            }
                        }
                    }
                }
            }

            Footer {}
        }
    }

    // ---- A to Z ------------------------------------------------------------

    Component {
        id: listLayout

        Column {
            spacing: 16

            SearchField {
                width: parent.width
                placeholder: "Filter applications"
            }

            Results {
                visible: menu.searching
                width: parent.width
                height: parent.height - 64 - 50
            }

            Item {
                id: az
                visible: !menu.searching
                width: parent.width
                height: parent.height - 64 - 50

                readonly property var groups: Apps.byLetter(menu.provider.applications)

                ListView {
                    id: letters
                    width: parent.width - 30
                    height: parent.height
                    clip: true
                    model: az.groups
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Column {
                        id: group
                        required property var modelData
                        width: letters.width

                        PanelText {
                            leftPadding: 10
                            topPadding: 8
                            bottomPadding: 4
                            text: group.modelData.letter
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.acc
                        }

                        Repeater {
                            model: group.modelData.apps

                            Rectangle {
                                id: listed
                                required property var modelData
                                width: group.width
                                height: 38
                                radius: Theme.radiusOf(12)
                                color: listedHover.hovered ? Theme.s2 : "transparent"

                                PanelIcon {
                                    id: listedIcon
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 22
                                    iconName: listed.modelData.icon ?? ""
                                }

                                PanelText {
                                    anchors.left: listedIcon.right
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    text: listed.modelData.name
                                    font.pixelSize: 14
                                }

                                HoverHandler { id: listedHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: menu.provider.launch(listed.modelData) }
                            }
                        }
                    }
                }

                // The index: a letter with applications under it can be
                // clicked; the rest are there to keep the column even.
                Column {
                    anchors.right: parent.right
                    width: 22
                    height: parent.height

                    Repeater {
                        model: "ABCDEFGHIJKLMNOPQRSTUVWXYZ#".split("")

                        PanelText {
                            id: indexLetter
                            required property string modelData
                            readonly property int at: az.groups.findIndex(g => g.letter === indexLetter.modelData)
                            width: 22
                            height: parent.height / 27
                            horizontalAlignment: Text.AlignHCenter
                            text: indexLetter.modelData
                            font.pixelSize: 10
                            color: indexLetter.at >= 0 ? Theme.acc : Theme.alpha(Theme.mut, 0.5)

                            TapHandler {
                                enabled: indexLetter.at >= 0
                                onTapped: letters.positionViewAtIndex(indexLetter.at, ListView.Beginning)
                            }
                        }
                    }
                }
            }

            Footer {}
        }
    }
}
