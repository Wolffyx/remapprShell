pragma ComponentBehavior: Bound

// The start menu in two panes: categories down a rail; pinned apps and recent
// files in the middle, or what the search found; and beside them you, what is
// playing, the machine, and the session.

import QtQuick
import QtQuick.Controls
import qs.domain.launcher
import qs.domain.launcher.apps
import qs.domain.launcher.providers
import qs.domain.theme
import qs.ui.primitives

Item {
    id: twoPane

    required property BuiltinProvider provider
    // The menu's field, which the search box here takes in.
    required property TextField field
    // Which part is showing: "home" (pinned and recent), a rail category,
    // "everything", or "recent" -- and whether a search is showing instead.
    required property string view
    required property bool searching
    signal viewChosen(string chosen)

    Rail {
        id: rail
        width: 78
        height: parent.height
        field: twoPane.field
        view: twoPane.view
        onViewChosen: chosen => twoPane.viewChosen(chosen)
    }

    // The middle.
    Column {
        id: middle
        x: rail.width + 24
        y: 22
        width: parent.width - rail.width - side.width - 48
        height: parent.height - 44
        spacing: 20

        SearchBox {
            width: parent.width
            provider: twoPane.provider
            field: twoPane.field
        }

        ResultList {
            visible: twoPane.searching
            width: parent.width
            provider: twoPane.provider
        }

        Flickable {
            visible: !twoPane.searching
            width: parent.width
            height: parent.height - 68
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width
                spacing: 14

                readonly property var shown: twoPane.view === "home" ? twoPane.provider.pinnedApps
                    : twoPane.view === "everything" ? Apps.inCategory(twoPane.provider.applications, "all")
                    : twoPane.view === "recent" ? []
                    : Apps.inCategory(twoPane.provider.applications, twoPane.view)

                Heading {
                    visible: twoPane.view !== "recent"
                    text: twoPane.view === "home" ? "Pinned"
                        : twoPane.view === "everything" ? "All apps"
                        : (Apps.categories.find(c => c.id === twoPane.view)?.label ?? "")
                    link: twoPane.view === "home" ? "All apps" : "Back"
                    onLinked: twoPane.viewChosen(twoPane.view === "home" ? "everything" : "home")
                }

                Grid {
                    visible: twoPane.view !== "recent"
                    columns: 5
                    columnSpacing: (body.width - 5 * 96) / 4
                    rowSpacing: 4

                    Repeater {
                        model: body.shown
                        AppTile {
                            provider: twoPane.provider
                            framed: twoPane.view === "home"
                        }
                    }
                }

                Heading {
                    visible: twoPane.view === "home" || twoPane.view === "recent"
                    text: "Recent"
                }

                Column {
                    visible: twoPane.view === "home" || twoPane.view === "recent"
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: twoPane.view === "recent" ? RecentFiles.files : RecentFiles.files.slice(0, 3)
                        RecentRow { provider: twoPane.provider }
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

    SidePane {
        id: side
        anchors.right: parent.right
        width: 276
        height: parent.height
        provider: twoPane.provider
    }
}
