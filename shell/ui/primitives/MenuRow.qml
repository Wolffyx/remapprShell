// One row of a menu: an icon, the words, and what is at the end of it.
//
// The icon is a Material Symbols `glyph`, a theme `iconName`, or an image
// `iconSource` an application supplied -- a tray item's menu brings its own.
// `check` draws a tick or a radio mark in its place, for an entry that shows
// a setting. `danger` is for the one row that destroys something.

import QtQuick
import qs.domain.theme

Item {
    id: root

    property string text: ""
    property string glyph: ""
    property string iconName: ""
    property string iconSource: ""
    // "", "check" or "radio"; `checked` says which way it is set.
    property string check: ""
    property bool checked: false
    // Trailing: a word ("off"), or a glyph ("chevron_right").
    property string trailing: ""
    property string trailingGlyph: ""
    property bool danger: false

    signal activated

    readonly property color ink: root.danger ? Theme.error : Theme.fg
    readonly property bool hasIcon: root.glyph.length > 0 || root.iconName.length > 0
                                    || root.iconSource.length > 0 || root.check.length > 0

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 38
    opacity: root.enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: hover.hovered && root.enabled ? Theme.s2 : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    Row {
        id: row
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasIcon
            width: 19
            height: 19

            Glyph {
                anchors.centerIn: parent
                visible: root.check.length > 0 || root.glyph.length > 0
                name: root.check === "radio" ? (root.checked ? "radio_button_checked" : "radio_button_unchecked")
                    : root.check === "check" ? (root.checked ? "check_box" : "check_box_outline_blank")
                    : root.glyph
                fallback: root.iconName
                size: 19
                color: root.check.length > 0 && root.checked ? Theme.acc : root.ink
            }

            PanelIcon {
                anchors.fill: parent
                visible: root.check.length === 0 && root.glyph.length === 0
                         && (root.iconName.length > 0 || root.iconSource.length > 0)
                iconName: root.iconName
                iconFile: root.iconSource
            }
        }

        PanelText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(label.implicitWidth, Math.max(80, root.width - 24 - row.spacing * 2
                   - (root.hasIcon ? 19 : 0) - end.width))
            elide: Text.ElideRight
            text: root.text
            font.pixelSize: 14
            color: root.ink
        }
    }

    Item {
        id: end
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: root.trailingGlyph.length > 0 ? 18 : trailingText.implicitWidth
        height: 18

        PanelText {
            id: trailingText
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            visible: root.trailingGlyph.length === 0
            text: root.trailing
            font.pixelSize: 12
            color: Theme.mut
        }

        Glyph {
            anchors.centerIn: parent
            visible: root.trailingGlyph.length > 0
            name: root.trailingGlyph
            size: 18
            color: Theme.mut
        }
    }

    HoverHandler { id: hover; cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler {
        enabled: root.enabled
        onTapped: root.activated()
    }
}
