// A single-line text setting.

import QtQuick
import QtQuick.Controls
import qs.domain.theme

TextField {
    id: root

    signal committed(string value)

    implicitHeight: 36
    color: Theme.fg
    placeholderTextColor: Theme.mut
    selectionColor: Theme.accC
    selectedTextColor: Theme.accCFg
    font.family: Theme.fontFamily
    font.pixelSize: 13
    leftPadding: 12
    rightPadding: 12
    selectByMouse: true

    // Committed on Enter or on losing focus, never on every keystroke: writing
    // a config file per character would be both noisy and, with live reload,
    // visibly jumpy.
    onEditingFinished: root.committed(text)

    background: Rectangle {
        radius: Theme.radiusTiny + 2
        color: Theme.s1
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Theme.acc : Theme.out
    }
}
