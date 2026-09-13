import QtQuick
import Quickshell
import qs.domain.config

ShellRoot {
    id: root
    readonly property string out: Quickshell.env("PREVIEW_OUT")
    readonly property int w: parseInt(Quickshell.env("PREVIEW_W"))
    readonly property int h: parseInt(Quickshell.env("PREVIEW_H"))
    readonly property string mode: Quickshell.env("PREVIEW_MODE")

    Component.onCompleted: {
        ConfigStore.setRuntime("theme.mode", root.mode);
        ConfigStore.setRuntime("services.hostPlasma", false);
    }

    FloatingWindow {
        implicitWidth: root.w
        implicitHeight: root.h
        visible: true
        color: "transparent"

        Rectangle {
            id: shot
            width: root.w
            height: root.h
            color: "#808080"
            PreviewTarget { anchors.fill: parent }
        }
    }

    Timer {
        running: true
        interval: parseInt(Quickshell.env("PREVIEW_DELAY")) || 2500
        onTriggered: shot.grabToImage(r => {
            r.saveToFile(root.out);
            console.info("preview: saved");
            Qt.quit();
        })
    }
}
