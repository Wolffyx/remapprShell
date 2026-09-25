// A script's own words, folded away: "Details" and, when opened, its output
// in a monospace box that scrolls. The installer's pages say what happened in
// sentences; this is for when the sentence is not enough.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Column {
    id: root

    property string text: ""
    property alias open: fold.open
    // Follow the end as lines arrive, as a terminal would.
    property bool follow: false

    spacing: 6
    visible: root.text.length > 0

    Fold {
        id: fold
        label: "Details"
    }

    Rectangle {
        visible: root.open
        width: parent.width
        height: 180
        radius: Theme.radiusSmall
        color: Theme.surfaceContainerLowest
        border.width: 1
        border.color: Theme.outlineVariant
        clip: true

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 10
            contentHeight: log.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            PanelText {
                id: log
                width: flick.width
                wrapMode: Text.WrapAnywhere
                text: root.text
                font.family: Theme.monoFamily
                font.pixelSize: 11
                color: Theme.fg
                onImplicitHeightChanged: if (root.follow) flick.contentY = Math.max(0, implicitHeight - flick.height)
            }
        }
    }
}
