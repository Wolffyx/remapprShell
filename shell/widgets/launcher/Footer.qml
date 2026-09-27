pragma ComponentBehavior: Bound

// The foot of the grid and list start menus: who is signed in, and the power
// button.

import QtQuick
import qs.domain.launcher.providers
import qs.domain.session
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Item {
    id: footer

    required property BuiltinProvider provider

    width: parent ? parent.width : 0
    height: 50

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.out
    }

    Avatar {
        id: footAvatar
        y: 14
        size: 34
        source: Session.avatar
        initial: Session.initial
    }

    PanelText {
        anchors.left: footAvatar.right
        anchors.leftMargin: 12
        anchors.verticalCenter: footAvatar.verticalCenter
        text: Session.displayName
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    IconButton {
        anchors.right: parent.right
        anchors.verticalCenter: footAvatar.verticalCenter
        glyph: "power_settings_new"
        iconName: "system-shutdown"
        onActivated: {
            Session.prompt("promptAll");
            footer.provider.close();
        }
    }
}
