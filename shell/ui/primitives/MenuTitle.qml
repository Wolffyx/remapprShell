// What a menu is about, over its rows: "WINDOW", or an application's name.

import QtQuick
import qs.domain.theme

PanelText {
    leftPadding: 12
    rightPadding: 12
    topPadding: 6
    bottomPadding: 8
    elide: Text.ElideRight
    font.family: Theme.monoFamily
    font.pixelSize: 11
    font.letterSpacing: 0.7
    font.capitalization: Font.AllUppercase
    color: Theme.mut
}
