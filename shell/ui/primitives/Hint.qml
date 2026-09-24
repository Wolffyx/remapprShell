// The small print under a setting: a sentence or two in 12 px, wrapped to
// the width it is given.
//
// Written out by hand it was six lines -- width, wrap, size, line height,
// colour -- forty-odd times across the settings pages, and a third of the
// copies had drifted from the rest on the line height alone. So the parts
// that never differ live here, and the two that do are properties:
//
//   tone        "muted" (the default) for an explanation, "error" for what
//               went wrong, "warning" for what is about to, "plain" for
//               ordinary text in the same size.
//   lineHeight  1.35 unless said otherwise. A one-line status is drawn at 1,
//               where the extra leading would only push what is under it
//               down.

import QtQuick
import qs.domain.theme

PanelText {
    id: root

    property string tone: "muted"

    width: parent ? parent.width : 0
    wrapMode: Text.WordWrap
    font.pixelSize: 12
    lineHeight: 1.35
    color: root.tone === "error" ? Theme.error
         : root.tone === "warning" ? Theme.warning
         : root.tone === "plain" ? Theme.fg
         : Theme.mut
}
