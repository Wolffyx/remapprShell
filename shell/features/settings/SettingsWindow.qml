pragma ComponentBehavior: Bound

// The settings window.
//
// An ordinary window rather than a panel or popup: settings are something you
// sit with, move around, and put beside the thing you are changing. A layer
// surface would sit above everything and could not be moved.
//
// The navigation is the schema's own list of sections, in the schema's order,
// so a page cannot exist without being documented -- and `rmpr settings <id>`
// opens the page the reference describes.

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.core
import qs.domain.theme
import qs.ui.primitives
import qs.features.settings.pages

FloatingWindow {
    id: root

    property var sections: []
    property int currentIndex: 0

    // A page asked for before the schema was read. `rmpr settings <page>` can
    // arrive in the first seconds of a session, when `sections` is still
    // empty and no index can be resolved; the name waits here until it can.
    property string requestedPage: ""

    readonly property var currentSection: root.sections[root.currentIndex] ?? null

    onSectionsChanged: root._resolveRequestedPage()
    onRequestedPageChanged: root._resolveRequestedPage()

    function _resolveRequestedPage(): void {
        if (!root.requestedPage || (root.sections?.length ?? 0) === 0)
            return;
        const index = root.sections.findIndex(s => s && s.id === root.requestedPage);
        if (index >= 0)
            root.currentIndex = index;
        else
            Log.warn("settings", `no such page: ${root.requestedPage}`);
        root.requestedPage = "";
    }

    title: `${Branding.displayName} settings`
    implicitWidth: 1120
    implicitHeight: 720
    color: Theme.s1

    Row {
        anchors.fill: parent

        // Navigation.
        Rectangle {
            id: nav

            width: 264
            height: parent.height
            color: Theme.s2

            Column {
                id: navTitle

                x: 22
                y: 20
                width: parent.width - 44
                spacing: 0

                Row {
                    spacing: 10

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "tune"
                        fallback: "configure"
                        size: 22
                        color: Theme.acc
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Branding.displayName} settings`
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }
                }
            }

            // Grouped under the schema's own headings -- Look, Behaviour,
            // System -- because twenty-odd pages in one list put half of them
            // below the fold with nothing to say they were there. A heading is
            // drawn wherever the group changes, so the schema's order is the
            // only order, and a section without a group simply has none.
            Flickable {
                id: navFlick

                x: 12
                y: navTitle.y + navTitle.height + 12
                width: parent.width - 24
                height: parent.height - y - version.height - 24
                clip: true
                contentHeight: navColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                // The page chosen from elsewhere -- `rmpr settings <page>`, the
                // launcher -- may be below the fold; bring it into view.
                function reveal(item) {
                    if (!item)
                        return;
                    const top = item.y;
                    const bottom = item.y + item.height;
                    if (top < navFlick.contentY)
                        navFlick.contentY = Math.max(0, top - 28);
                    else if (bottom > navFlick.contentY + navFlick.height)
                        navFlick.contentY = Math.min(navFlick.contentHeight - navFlick.height, bottom - navFlick.height + 8);
                }

                Column {
                    id: navColumn

                    width: navFlick.width
                    spacing: 1

                    Repeater {
                        model: root.sections

                        Column {
                            id: navEntry

                            required property var modelData
                            required property int index

                            readonly property string group: navEntry.modelData.group ?? ""
                            readonly property bool startsGroup: navEntry.group.length > 0
                                && (navEntry.index === 0 || (root.sections[navEntry.index - 1]?.group ?? "") !== navEntry.group)
                            readonly property bool current: navEntry.index === root.currentIndex

                            width: navColumn.width

                            onCurrentChanged: if (navEntry.current) Qt.callLater(() => navFlick.reveal(navEntry))

                            PanelText {
                                visible: navEntry.startsGroup
                                leftPadding: 12
                                topPadding: navEntry.index === 0 ? 2 : 14
                                bottomPadding: 6
                                text: navEntry.group.toUpperCase()
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.letterSpacing: 0.8
                                color: Theme.mut
                            }

                            Rectangle {
                                id: navItem

                                width: parent.width
                                height: 36
                                radius: Theme.radiusOf(10)
                                color: navEntry.current ? Theme.accC
                                     : (navHover.hovered ? Theme.hover : "transparent")

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    Glyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: navEntry.modelData.glyph ?? "tune"
                                        fallback: navEntry.modelData.icon ?? "configure"
                                        size: 18
                                        color: navEntry.current ? Theme.accCFg : Theme.mut
                                    }

                                    PanelText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 30
                                        elide: Text.ElideRight
                                        text: navEntry.modelData.label ?? navEntry.modelData.id
                                        font.pixelSize: 13
                                        font.weight: navEntry.current ? Font.Medium : Font.Normal
                                        color: navEntry.current ? Theme.accCFg : Theme.fg
                                    }
                                }

                                HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: root.currentIndex = navEntry.index }
                            }
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar { policy: navFlick.contentHeight > navFlick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
            }

            // What is running, in the words a bug report would need.
            Rectangle {
                id: version

                x: 12
                width: parent.width - 24
                height: versionText.implicitHeight + 24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                radius: Theme.radiusOf(14)
                color: Theme.s1

                Column {
                    id: versionText

                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24
                    spacing: 2

                    PanelText {
                        text: `${Branding.slug} ${Branding.version}`
                        font.family: Theme.monoFamily
                        font.pixelSize: 12
                        color: Theme.mut
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    PanelText {
                        text: "quickshell · wayland"
                        font.family: Theme.monoFamily
                        font.pixelSize: 12
                        color: Theme.mut
                    }
                }
            }
        }

        // Page area.
        Item {
            width: parent.width - nav.width
            height: parent.height

            Item {
                id: header

                x: 30
                y: 22
                width: parent.width - 60
                height: 40

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentSection?.label ?? ""
                    font.pixelSize: 26
                    font.weight: Font.Medium
                }

                Rectangle {
                    id: closeButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    radius: width / 2
                    color: closeHover.hovered ? Theme.s2 : "transparent"

                    Glyph {
                        anchors.centerIn: parent
                        name: "close"
                        fallback: "window-close"
                        size: 20
                        color: Theme.mut
                    }

                    HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.visible = false }
                }
            }

            ScrollView {
                x: 30
                y: header.y + header.height + 4
                width: parent.width - 60
                height: parent.height - y - 20
                clip: true

                Column {
                    id: page

                    width: root.width - nav.width - 76
                    spacing: 16

                    Hint {
                        visible: (root.currentSection?.description ?? "").length > 0
                        text: root.currentSection?.description ?? ""
                    }

                    // A section either lists keys, which the schema renderer turns
                    // into controls, or names a page that needs more than a list of
                    // settings. Nothing here knows what any individual setting is.
                    Loader {
                        width: parent.width
                        active: root.currentSection !== null
                        sourceComponent: {
                            const page = root.currentSection?.page;
                            if (!page)
                                return keysPage;
                            switch (page) {
                                case "renderer":  return rendererPage;
                                case "ai":        return aiPage;
                                case "presets":   return presetsPage;
                                case "widgets":   return widgetsPage;
                                case "tray":      return trayPage;
                                case "edges":     return edgesPage;
                                case "shortcuts": return shortcutsPage;
                                case "switching": return switchingPage;
                                case "appearance": return appearancePage;
                                case "taskbar":   return taskbarPage;
                                case "windows":   return windowsPage;
                                case "launcher":  return launcherPage;
                                case "notifications": return notificationsPage;
                                case "lock":      return lockPage;
                                case "profiles":  return profilesPage;
                                case "snapshots": return snapshotsPage;
                                case "about":     return aboutPage;
                                default:          return keysPage;
                            }
                        }
                    }

                    Component {
                        id: keysPage
                        SchemaRenderer {
                            width: parent.width
                            title: root.currentSection?.label ?? ""
                            keys: root.currentSection?.keys ?? ({})
                        }
                    }

                    Component { id: rendererPage;  RendererPage  { width: parent.width } }
                    Component { id: aiPage;        AiPage        { width: parent.width } }
                    Component { id: presetsPage;   PresetsPage   { width: parent.width } }
                    Component { id: widgetsPage;   WidgetsPage   { width: parent.width } }
                    Component { id: trayPage;      TrayPage      { width: parent.width } }
                    Component { id: edgesPage;     EdgesPage     { width: parent.width } }
                    Component { id: shortcutsPage; ShortcutsPage { width: parent.width } }
                    Component { id: switchingPage; SwitchingPage { width: parent.width } }
                    Component { id: appearancePage; AppearancePage { width: parent.width } }
                    Component {
                        id: taskbarPage
                        TaskbarPage {
                            width: parent.width
                            openPage: id => root.currentIndex = Math.max(0, root.sections.findIndex(s => s.id === id))
                        }
                    }
                    Component { id: windowsPage;   WindowsPage   { width: parent.width } }
                    Component { id: launcherPage;  LauncherPage  { width: parent.width } }
                    Component { id: notificationsPage; NotificationsPage { width: parent.width } }
                    Component { id: lockPage;      LockPage      { width: parent.width } }
                    Component { id: profilesPage;  ProfilesPage  { width: parent.width } }
                    Component { id: snapshotsPage; SnapshotsPage { width: parent.width } }
                    Component { id: aboutPage;     AboutPage     { width: parent.width } }
                }
            }
        }
    }
}
