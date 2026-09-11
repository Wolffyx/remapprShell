// Text in the shell. Exists so no widget hardcodes a colour, a font or a size,
// which is what would make the shell stop following its theme.

import QtQuick
import qs.domain.theme

Text {
    color: Theme.fg
    font.family: Theme.fontFamily
    font.pixelSize: 13
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
}
