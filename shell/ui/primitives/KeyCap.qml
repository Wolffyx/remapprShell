// A key, drawn as a key: the chips in a switcher's hints -- "Tab", "Esc",
// "Meta+Tab" -- that say what pressing it does.
//
// The window switcher and the overview each drew their own, the same but for
// the size of the letters; `pixelSize` is that difference.

import QtQuick
import qs.domain.theme

Rectangle {
    id: root

    property alias text: label.text
    property int pixelSize: 12

    implicitWidth: label.implicitWidth + 18
    implicitHeight: 22
    radius: 8
    color: Theme.s2
    border.width: 1
    border.color: Theme.out

    PanelText {
        id: label
        anchors.centerIn: parent
        font.pixelSize: root.pixelSize
        font.weight: Font.Medium
        color: Theme.fg
    }
}
