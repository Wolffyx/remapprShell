// A small round icon button.
//
// `glyph` is a Material Symbols name, `iconName` a theme icon; the glyph is
// drawn where the font is installed and the theme icon otherwise.
//
// `tooltip` is shown on hover and is the button's accessible name. It was
// set on seven buttons and shown by none of them -- one of which, the
// restore point's "click again to restore", was the only place the second
// click was explained.

import QtQuick
import QtQuick.Controls
import qs.ui.primitives
import qs.domain.theme

Item {
    id: root

    property string iconName: ""
    property string glyph: ""
    property string tooltip: ""
    property real size: 34
    property color color: Theme.fg
    signal activated

    implicitWidth: root.size
    implicitHeight: root.size

    ToolTip.visible: hover.hovered && root.tooltip.length > 0
    ToolTip.text: root.tooltip
    ToolTip.delay: 600

    Accessible.role: Accessible.Button
    Accessible.name: root.tooltip
    Accessible.onPressAction: root.activated()

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: hover.hovered ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        Glyph {
            anchors.centerIn: parent
            visible: root.glyph.length > 0
            name: root.glyph
            fallback: root.iconName
            size: Math.round(root.size * 0.56)
            color: root.color
        }

        PanelIcon {
            anchors.centerIn: parent
            visible: root.glyph.length === 0
            implicitSize: Math.round(root.size * 0.47)
            iconName: root.iconName
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.activated() }
    }
}
