pragma ComponentBehavior: Bound

// The start menu's search field, as each layout draws it: a lens, the text
// typed, and a badge naming the prefix that offers the shell's actions.
//
// The text field itself is the menu's, one for every layout, typed into from
// anywhere in the menu; this is the frame it is shown in, and it takes the
// field into itself once it is built. It is not called SearchField because
// QtQuick.Controls has one, and a file of that name here would collide with
// it wherever Controls is imported.

import QtQuick
import QtQuick.Controls
import qs.domain.launcher.providers
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: box

    required property BuiltinProvider provider
    // The menu's field, reparented into this.
    required property TextField field
    property string placeholder: "Search apps, files and actions"

    height: 48
    radius: Theme.radiusOf(16)
    // An outline rather than a fill: a field drawn a shade lighter than the
    // menu it sits in is one more background to read past, and the border
    // says "type here" on its own.
    color: "transparent"
    border.width: 1
    border.color: box.field.activeFocus ? Theme.acc : Theme.out

    Glyph {
        id: lens
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: 20
        color: Theme.mut
    }

    Rectangle {
        id: badge
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: badgeText.implicitWidth + 14
        height: 22
        radius: Theme.radiusOf(6)
        color: Theme.s1

        PanelText {
            id: badgeText
            anchors.centerIn: parent
            text: `${box.provider.prefix} actions`
            font.family: Theme.monoFamily
            font.pixelSize: 11
            color: Theme.mut
        }
    }

    // Reparented into whichever layout is showing.
    Item {
        id: fieldSlot
        anchors.left: lens.right
        anchors.leftMargin: 10
        anchors.right: badge.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        Component.onCompleted: box.field.parent = fieldSlot
    }

    PanelText {
        anchors.left: lens.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: box.field.text.length === 0
        text: box.placeholder
        font.pixelSize: 15
        color: Theme.mut
    }
}
