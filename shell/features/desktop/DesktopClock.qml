pragma ComponentBehavior: Bound

// The clock on the desktop: the time, large and thin, with the date under it.
//
// Off by default, and drawn on the background layer, so it sits on the
// wallpaper and every window covers it -- which is what a desktop clock is.
// It takes no input at all: a click where it happens to be lands on the
// desktop, as it would if the clock were painted into the wallpaper.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.config
import qs.domain.theme
import qs.ui.primitives

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property string position: ConfigStore.value("desktop.clockPosition", "bottom-right")
    readonly property int size: Math.max(24, ConfigStore.value("desktop.clockSize", 92))
    readonly property bool showDate: ConfigStore.value("desktop.clockDate", true) === true
    readonly property string ink: ConfigStore.value("desktop.clockInk", "auto")

    // Over a wallpaper nothing here can read, and the shadow does the work
    // either way. "auto" follows the scheme, on the grounds that someone
    // running the dark scheme most likely has a dark wallpaper.
    readonly property color textColor: root.ink === "light" ? "#ffffff"
        : root.ink === "dark" ? "#221f1c"
        : (Theme.dark ? "#ffffff" : "#221f1c")

    readonly property bool atLeft: root.position.endsWith("left")
    readonly property bool atTop: root.position.startsWith("top")

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: 0
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: `${Branding.slug}-desktop-clock`
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
    }

    Column {
        x: root.atLeft ? Math.round(root.width * 0.05) : root.width - width - Math.round(root.width * 0.05)
        y: root.atTop ? Math.round(root.height * 0.1) : root.height - height - Math.round(root.height * 0.14)
        spacing: 6

        PanelText {
            anchors.right: root.atLeft ? undefined : parent.right
            text: root.clock.date.toLocaleTimeString(Qt.locale(),
                    ConfigStore.value("widgets.clock.hour12", false) === true ? "h:mm AP" : "HH:mm")
            color: root.textColor
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.22)
            font.pixelSize: root.size
            font.weight: Font.Light
            font.letterSpacing: -Math.round(root.size * 0.02)
        }

        PanelText {
            anchors.right: root.atLeft ? undefined : parent.right
            visible: root.showDate
            text: root.clock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)
            color: root.textColor
            opacity: 0.75
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.22)
            font.pixelSize: Math.max(12, Math.round(root.size * 0.21))
        }
    }
}
