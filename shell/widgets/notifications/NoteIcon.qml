pragma ComponentBehavior: Bound

// An application's icon as a notification names it -- a theme name or a path
// -- or the bell.

import QtQuick
import qs.domain.theme
import qs.ui.primitives

Item {
    id: icon

    property string source: ""
    property real size: 18
    readonly property bool isPath: icon.source.startsWith("/") || icon.source.startsWith("file:")

    implicitWidth: icon.size
    implicitHeight: icon.size

    PanelIcon {
        anchors.fill: parent
        visible: icon.source.length > 0
        iconName: icon.isPath ? "" : icon.source
        iconFile: icon.isPath ? icon.source : ""
    }

    Glyph {
        anchors.centerIn: parent
        visible: icon.source.length === 0
        name: "notifications"
        size: icon.size
        color: Theme.acc
    }
}
