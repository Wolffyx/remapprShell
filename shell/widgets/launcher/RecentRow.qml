pragma ComponentBehavior: Bound

// A recent file in the start menu: its name, and the folder it is in. Clicking
// it opens the file and puts the menu away.

import QtQuick
import qs.domain.launcher
import qs.domain.launcher.providers
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    id: recent

    required property var modelData
    required property BuiltinProvider provider

    width: parent ? parent.width : 0
    height: 40
    radius: Theme.radiusOf(14)
    color: recentHover.hovered ? Theme.s2 : "transparent"

    Glyph {
        id: recentGlyph
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        name: recent.modelData.folder ? "folder_open" : "description"
        size: 20
        color: Theme.mut
    }

    PanelText {
        anchors.left: recentGlyph.right
        anchors.leftMargin: 14
        anchors.right: recentDir.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: recent.modelData.name
        font.pixelSize: 14
    }

    PanelText {
        id: recentDir
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 200)
        elide: Text.ElideMiddle
        text: recent.modelData.dir
        font.family: Theme.monoFamily
        font.pixelSize: 12
        color: Theme.mut
    }

    HoverHandler { id: recentHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        onTapped: {
            RecentFiles.open(recent.modelData);
            recent.provider.close();
        }
    }
}
