// A widget's tooltip: a second window beside the panel, because a tooltip
// has to escape the panel just as a popout does, and the popout's is spoken
// for. The first line is the name of the thing, any further lines detail.
//
// When it shows is WidgetSlot's to decide -- the pointer resting, a request
// over IPC, never over an open popout -- so this only draws what it is given.

import QtQuick
import Quickshell
import qs.ui.primitives
import qs.domain.theme

EdgeWindow {
    id: tip

    required property string text

    readonly property var lines: tip.text.split("\n")

    gap: 10

    // Takes no input at all: a pointer that strays onto a tooltip must not
    // be caught by it, and the widget under it must stay reachable.
    mask: Region {}

    implicitWidth: tipColumn.width + 24
    implicitHeight: tipColumn.implicitHeight + 14

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.tipBg

        Column {
            id: tipColumn
            anchors.centerIn: parent
            width: Math.min(360, Math.max(tipFirst.implicitWidth, tipRest.visible ? tipRest.implicitWidth : 0))
            spacing: 2

            PanelText {
                id: tipFirst
                width: parent.width
                wrapMode: Text.Wrap
                text: tip.lines[0] ?? ""
                color: Theme.tipFg
                font.pixelSize: 13
            }

            PanelText {
                id: tipRest
                visible: tip.lines.length > 1
                width: parent.width
                wrapMode: Text.Wrap
                text: tip.lines.slice(1).join("\n")
                color: Theme.tipFgMut
                font.pixelSize: 12
            }
        }
    }
}
