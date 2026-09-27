pragma ComponentBehavior: Bound

// The start menu as a list: every application, A to Z, with an index down the
// side.

import QtQuick
import QtQuick.Controls
import qs.domain.launcher.apps
import qs.domain.launcher.providers
import qs.domain.theme
import qs.ui.primitives

Column {
    id: listMenu

    required property BuiltinProvider provider
    // The menu's field, which the search box here takes in, and whether a
    // search is showing rather than the list.
    required property TextField field
    required property bool searching

    spacing: 16

    SearchBox {
        width: parent.width
        provider: listMenu.provider
        field: listMenu.field
        placeholder: "Filter applications"
    }

    ResultList {
        visible: listMenu.searching
        width: parent.width
        height: parent.height - 64 - 50
        provider: listMenu.provider
    }

    Item {
        id: az
        visible: !listMenu.searching
        width: parent.width
        height: parent.height - 64 - 50

        readonly property var groups: Apps.byLetter(listMenu.provider.applications)

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
                        TapHandler { onTapped: listMenu.provider.launch(listed.modelData) }
                    }
                }
            }
        }

        // The index: a letter with applications under it can be clicked; the
        // rest are there to keep the column even.
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

    Footer { provider: listMenu.provider }
}
