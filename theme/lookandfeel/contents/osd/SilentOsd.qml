/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Plasma's OSD, drawn as nothing.

    Installed in place of Osd.qml when the shell draws its own OSD instead.
    plasmashell still creates this window and still drives every property on
    it -- the signals our OSD listens to are emitted either way -- so the
    interface is kept exactly as plasmashell expects and only the drawing is
    removed. A file that merely failed to load would leave errors in the
    journal on every volume key.

    `rmpr theme osd plasma` puts the real one back.
*/

// The base type lives in plasmashell's own qrc, which the linter cannot see.
// qmllint disable unqualified
import QtQuick
import org.kde.plasma.workspace.osd

OsdWindow {
    id: root

    property alias timeout: silent.timeout
    property alias osdValue: silent.osdValue
    property alias osdMaxValue: silent.osdMaxValue
    property alias osdAdditionalText: silent.osdAdditionalText
    property alias icon: silent.icon
    property alias showingProgress: silent.showingProgress

    visible: false
    width: 0
    height: 0

    mainItem: Item {
        id: silent

        property int timeout: 0
        property int osdValue: 0
        property int osdMaxValue: 0
        property string osdAdditionalText: ""
        property string icon: ""
        property bool showingProgress: false

        implicitWidth: 0
        implicitHeight: 0
    }
}
