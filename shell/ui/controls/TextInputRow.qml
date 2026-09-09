// A single-line text setting.

import QtQuick
import QtQuick.Controls
import qs.domain.theme

TextField {
    id: root

    signal committed(string value)

    implicitHeight: 28
    color: PlasmaColors.foreground
    font.pixelSize: 12
    selectByMouse: true

    // Committed on Enter or on losing focus, never on every keystroke: writing
    // a config file per character would be both noisy and, with live reload,
    // visibly jumpy.
    onEditingFinished: root.committed(text)

    background: Rectangle {
        radius: 5
        color: PlasmaColors.backgroundAlternate
        border.width: 1
        border.color: root.activeFocus ? PlasmaColors.accent
                                       : PlasmaColors.alpha(PlasmaColors.foreground, 0.15)
    }
}
