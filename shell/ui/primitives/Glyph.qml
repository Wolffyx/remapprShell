pragma ComponentBehavior: Bound

// An icon from Material Symbols, drawn from its name.
//
// The font draws each icon as a ligature of its name ("wifi", "volume_up"),
// so an icon is a word and costs nothing to add. Where the font is not
// installed the word would be drawn as a word, so the icon theme stands in:
// `fallback` names a theme icon, and without one nothing is drawn rather than
// a stray word on the panel.

import QtQuick
import qs.domain.theme

Item {
    id: root

    property string name: ""
    property string fallback: ""
    property real size: 20
    property color color: Theme.fg
    // Material Symbols' FILL axis, 0 or 1: an outline or a solid icon.
    property bool filled: false

    implicitWidth: root.size
    implicitHeight: root.size

    Text {
        anchors.centerIn: parent
        visible: Theme.hasIconFont
        text: root.name
        color: root.color
        font.family: Theme.iconFont
        font.pixelSize: root.size
        font.variableAxes: ({ "FILL": root.filled ? 1 : 0, "opsz": Math.max(20, Math.min(48, root.size)) })
        renderType: Text.QtRendering
    }

    Loader {
        anchors.centerIn: parent
        active: !Theme.hasIconFont && root.fallback.length > 0
        sourceComponent: PanelIcon {
            implicitSize: root.size
            iconName: root.fallback
        }
    }
}
