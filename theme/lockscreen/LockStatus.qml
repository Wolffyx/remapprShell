/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What the machine can say for itself at a locked screen: the on-screen
    keyboard, the keyboard layout, and the battery.

    All three are Plasma's own controls. The layout is named as the person set
    it up and is one press away from the next one; the battery is the same
    indicator the panel draws. Nothing here knows the network: the greeter has
    no session to ask, and a Wi-Fi name drawn from nowhere would be a guess.

    A Row, uncoloured and unbacked, so a style can put it in a pill, on a bar,
    or in a line of monospace.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.workspace.components as PW
import org.kde.breeze.components as Breeze

Row {
    id: status

    // The frame, for its on-screen keyboard: whether there is one, whether
    // it is up, and the press that shows or hides it. A var rather than
    // LockUi, which loads the style that makes this. Null draws no button.
    property var ui: null

    property color ink: "#ffffff"
    // Caps Lock, and a layout that is not the person's first: the two things
    // that make a right password wrong. Said here in this colour, and in
    // words under the field by LockMessage.
    property color warn: "#e0c98a"
    property int textSize: 12

    // The frame asks Kirigami for light-on-dark, which is right for five of
    // the seven styles and invisible on the two that draw dark type on a
    // light ground. Plasma's battery and the field's reveal button are
    // Kirigami's to colour, so the style's ink is handed over here rather
    // than fought with afterwards.
    Kirigami.Theme.inherit: false
    Kirigami.Theme.textColor: status.ink

    spacing: 14

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: LockKeys.caps
        text: "keyboard_capslock"
        font.family: "Material Symbols Rounded"
        font.pixelSize: Math.round(status.textSize * 1.5)
        color: status.warn
        Accessible.name: "Caps Lock is on"
    }

    PlasmaComponents3.ToolButton {
        anchors.verticalCenter: parent.verticalCenter
        focusPolicy: Qt.TabFocus
        text: "On-screen keyboard"
        display: QQC2.AbstractButton.IconOnly
        icon.name: status.ui?.keyboardShown ? "input-keyboard-virtual-on" : "input-keyboard-virtual-off"
        visible: status.ui?.keyboardAvailable ?? false
        onClicked: status.ui.toggleKeyboard()
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        visible: layouts.hasMultipleKeyboardLayouts
        width: layoutText.width
        height: layoutText.height

        Text {
            id: layoutText
            text: layouts.layoutNames.shortName
            textFormat: Text.PlainText
            font.family: "monospace"
            font.pixelSize: status.textSize
            color: LockKeys.otherLayout ? status.warn : status.ink
        }

        PW.KeyboardLayoutSwitcher {
            id: layouts
            anchors.fill: parent
        }
    }

    Breeze.Battery {
        anchors.verticalCenter: parent.verticalCenter
    }
}
