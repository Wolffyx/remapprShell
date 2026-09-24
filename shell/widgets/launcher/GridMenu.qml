pragma ComponentBehavior: Bound

// The start menu as a grid: pinned apps, or all of them, and the two most
// recent files under them as recommendations.

import QtQuick
import QtQuick.Controls
import qs.domain.launcher
import qs.domain.launcher.apps
import qs.domain.launcher.providers
import qs.domain.theme
import qs.ui.primitives

Column {
    id: grid

    required property BuiltinProvider provider
    // The menu's field, which the search box here takes in.
    required property TextField field
    // "everything" for every application, anything else for the pinned --
    // and whether a search is showing instead.
    required property string view
    required property bool searching
    signal viewChosen(string chosen)

    spacing: 18

    SearchBox {
        width: parent.width
        provider: grid.provider
        field: grid.field
        placeholder: "Type to search"
    }

    ResultList {
        visible: grid.searching
        width: parent.width
        height: parent.height - 66 - 50
        provider: grid.provider
    }

    Column {
        visible: !grid.searching
        width: parent.width
        height: parent.height - 66 - 50
        spacing: 12

        Heading {
            text: grid.view === "everything" ? "All apps" : "Pinned"
            link: grid.view === "everything" ? "Back" : "All apps"
            onLinked: grid.viewChosen(grid.view === "everything" ? "home" : "everything")
        }

        Flickable {
            width: parent.width
            height: grid.view === "everything" ? parent.height - 34 : pinnedGrid.implicitHeight
            contentHeight: pinnedGrid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Grid {
                id: pinnedGrid
                columns: 4
                columnSpacing: (parent.width - 4 * 96) / 3
                rowSpacing: 2

                Repeater {
                    model: grid.view === "everything" ? Apps.inCategory(grid.provider.applications, "all")
                                                      : grid.provider.pinnedApps.slice(0, 12)
                    AppTile {
                        provider: grid.provider
                        framed: false
                    }
                }
            }
        }

        Heading {
            visible: grid.view !== "everything"
            text: "Recommended"
        }

        Grid {
            visible: grid.view !== "everything"
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
                            grid.provider.close();
                        }
                    }
                }
            }
        }
    }

    Footer { provider: grid.provider }
}
