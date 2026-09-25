pragma ComponentBehavior: Bound

// One card of the sidebar: a heading that folds it, the part always shown,
// and the part that appears when it is open. Every card the sidebar draws is
// one of these (SidebarMediaCard and the rest), filled with its own rows.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: box

    required property string cardId
    required property string title
    required property string glyph
    property bool foldable: true
    property alias content: inner.data

    // What an open card adds, as a component rather than as children:
    // the month grid, the forecast and the rest are built when the card
    // opens and destroyed when it folds. Each card's is a Column, spaced
    // as the card's own rows are.
    property Component extra: null

    // Whether the sidebar has this card open. That is the sidebar's to keep
    // -- it is a setting, see Sidebar.qml -- so the card is told, and a tap
    // on its heading only asks: `fold`.
    required property bool expanded
    signal fold()

    readonly property bool open: box.foldable ? box.expanded : true

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
                onTapped: box.fold()
            }
        }

        Column {
            id: inner
            width: parent.width
            spacing: 12
        }

        // Built only while it is open, and destroyed when it folds: the
        // month grid and the forecast are not worth keeping alive behind
        // a closed card. It used to say so over children that were only
        // hidden -- a folded day card still ran the forecast lookup for
        // every day of the month.
        Item {
            id: more
            width: parent.width
            visible: box.open
            implicitHeight: extraLoader.implicitHeight
            height: box.open ? implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Theme.animationMs; easing.type: Easing.OutCubic } }

            Loader {
                id: extraLoader
                width: parent.width
                active: box.open
                sourceComponent: box.extra
            }
        }
    }
}
