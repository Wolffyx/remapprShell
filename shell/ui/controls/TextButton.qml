// A button with words on it, for the action a bare icon cannot name.
//
// `checked` marks the current choice in a row of them -- a power profile, say
// -- so a set of alternatives needs no separate control. `primary` is the one
// action a card exists for, drawn in the accent. `tonal` is the quieter way to
// say "do this", once per row of a list -- Use on a profile, Apply on a
// layout: the accent's container colour, turning to the accent itself under
// the pointer.

import QtQuick
import qs.ui.primitives
import qs.domain.theme

Item {
    id: root

    property string text: ""
    // A theme icon, or a Material Symbols name in `glyph`.
    property string iconName: ""
    property string glyph: ""
    property bool checked: false
    property bool primary: false
    property bool tonal: false
    property real radius: Math.min(height / 2, Theme.radiusSmall)
    signal activated

    readonly property bool filled: root.checked || root.primary

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34

    opacity: root.enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.filled ? Theme.acc
             : root.tonal ? (hover.hovered ? Theme.acc : Theme.accC)
             : hover.hovered ? Theme.alpha(Theme.fg, 0.12)
             : Theme.alpha(Theme.fg, 0.06)
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.glyph.length > 0
                name: root.glyph
                fallback: root.iconName
                size: 18
                color: label.color
            }

            PanelIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.glyph.length === 0 && root.iconName.length > 0
                implicitSize: 16
                iconName: root.iconName
            }

            PanelText {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: root.filled ? Theme.accFg
                     : root.tonal ? (hover.hovered ? Theme.accFg : Theme.accCFg)
                     : Theme.fg
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.activated() }
    }
}
