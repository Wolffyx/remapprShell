pragma ComponentBehavior: Bound

// The settings window.
//
// An ordinary window rather than a panel or popup: settings are something you
// sit with, move around, and put beside the thing you are changing. A layer
// surface would sit above everything and could not be moved.

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

    readonly property var currentSection: root.sections[root.currentIndex] ?? null

    title: `${Branding.displayName} settings`
    implicitWidth: 880
    implicitHeight: 560
    color: PlasmaColors.background

    Row {
        anchors.fill: parent

        // Navigation.
        Rectangle {
            width: 220
            height: parent.height
            color: PlasmaColors.backgroundAlternate

            Column {
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 2

                Repeater {
                    model: root.sections

                    Rectangle {
                        id: navItem

                        required property var modelData
                        required property int index

                        width: parent.width
                        height: 36
                        color: navItem.index === root.currentIndex
                            ? PlasmaColors.alpha(PlasmaColors.accent, 0.25)
                            : (navHover.hovered ? PlasmaColors.hoverBackground : "transparent")

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 10

                            PanelIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 18
                                iconName: navItem.modelData.icon ?? "configure"
                            }

                            PanelText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: navItem.modelData.label ?? navItem.modelData.id
                            }
                        }

                        HoverHandler { id: navHover }
                        TapHandler { onTapped: root.currentIndex = navItem.index }
                    }
                }
            }
        }

        // Page area.
        ScrollView {
            width: parent.width - 220
            height: parent.height
            clip: true

            Column {
                width: root.width - 260
                x: 20
                y: 16
                spacing: 12

                PanelText {
                    text: root.currentSection?.label ?? ""
                    font.pixelSize: 20
                }

                PanelText {
                    visible: (root.currentSection?.description ?? "").length > 0
                    text: root.currentSection?.description ?? ""
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: PlasmaColors.foregroundInactive
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
                            case "switching": return switchingPage;
                            case "appearance": return appearancePage;
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
                        keys: root.currentSection?.keys ?? ({})
                    }
                }

                Component { id: rendererPage;  RendererPage  { width: parent.width } }
                Component { id: aiPage;        AiPage        { width: parent.width } }
                Component { id: presetsPage;   PresetsPage   { width: parent.width } }
                Component { id: widgetsPage;   WidgetsPage   { width: parent.width } }
                Component { id: trayPage;      TrayPage      { width: parent.width } }
                Component { id: edgesPage;     EdgesPage     { width: parent.width } }
                Component { id: switchingPage; SwitchingPage { width: parent.width } }
                Component { id: appearancePage; AppearancePage { width: parent.width } }
                Component { id: profilesPage;  ProfilesPage  { width: parent.width } }
                Component { id: snapshotsPage; SnapshotsPage { width: parent.width } }
                Component { id: aboutPage;     AboutPage     { width: parent.width } }
            }
        }
    }
}
