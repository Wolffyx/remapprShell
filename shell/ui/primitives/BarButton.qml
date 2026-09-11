// The tile a panel widget draws itself on.
//
// Sized from the panel's thickness, so a thicker panel gets bigger buttons
// and a thin one keeps its icons readable -- the proportions are the design's
// at 64 px, scaled. A widget says what it is (a glyph, perhaps a word) and
// what state it is in; the look of each state lives here once.
//
//   plain     transparent until hovered
//   filled    a raised pill: the search field
//   accent    filled with the accent: the start button
//   selected  the thing currently in use: the focused window

import QtQuick
import qs.domain.theme

Item {
    id: root

    required property real thickness
    property bool vertical: false

    property bool hovered: false
    // Its popout is open.
    property bool active: false

    property bool filled: false
    property bool accent: false
    property bool selected: false

    property string glyph: ""
    // A theme icon, where Material Symbols is not installed.
    property string fallback: ""
    property string text: ""
    property real glyphSize: Math.max(16, Math.round(20 * root.unit))

    // The design's proportions are for a 64 px panel.
    readonly property real unit: root.thickness / 64
    property real size: Math.max(22, Math.round(44 * root.unit))

    readonly property bool showText: root.text.length > 0 && !root.vertical
    readonly property real padding: Math.round(14 * Math.max(0.75, root.unit))

    readonly property color contentColor: root.accent ? Theme.accFg
                                         : root.filled ? Theme.mut
                                         : Theme.fg

    implicitWidth: root.showText ? content.implicitWidth + 2 * root.padding : root.size
    implicitHeight: root.size

    Rectangle {
        anchors.fill: parent
        radius: Math.round(root.size * 0.32)
        color: root.accent ? Theme.acc
             : root.selected ? Theme.accC
             : root.filled ? ((root.hovered || root.active) ? Theme.s3 : Theme.s2)
             : (root.hovered || root.active) ? Theme.s2 : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        // The accent tile has no lighter surface to turn to, so hovering it
        // lays the text colour over it thinly, as Material's state layers do.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: root.accent
            color: Theme.alpha(Theme.accFg, root.active ? 0.16 : root.hovered ? 0.08 : 0)
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Math.round(10 * Math.max(0.7, root.unit))

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph.length > 0
            name: root.glyph
            fallback: root.fallback
            size: root.glyphSize
            color: root.contentColor
        }

        // No glyph named: the theme icon itself.
        PanelIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph.length === 0 && root.fallback.length > 0
            implicitSize: root.glyphSize
            iconName: root.fallback
        }

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showText
            text: root.text
            font.pixelSize: Math.max(12, Math.round(14 * Math.min(1, Math.max(0.85, root.unit))))
            color: root.contentColor
        }
    }
}
