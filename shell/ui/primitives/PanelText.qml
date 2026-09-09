// Text in the panel. Exists so no widget hardcodes a colour or a font size,
// which is what would make the shell stop following the system theme.

import QtQuick
import qs.domain.theme

Text {
    color: PlasmaColors.foreground
    font.pixelSize: 13
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
}
