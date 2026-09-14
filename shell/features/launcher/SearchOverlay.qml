// The built-in search, over the whole screen, as the design draws it.
//
// A layer surface on the overlay layer that asks for the keyboard outright,
// so it can be typed into the moment it opens -- from a key, from the panel,
// or from `rmpr search`. A click outside the card closes it, as Escape does.
// The card is SearchCard; what it finds and what a choice does are the
// built-in provider's.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.domain.launcher
import qs.domain.theme

PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    // Top, not overlay: the overlay layer is above a full-screen window, and
    // the search covering a game or Spectacle's region selector is not what
    // anyone asked for. See EdgeWindow.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    BackgroundEffect.blurRegion: Theme.translucent ? win._blur : null
    readonly property Region _blur: Region { item: card; radius: card.radius }

    property real shown: 0

    NumberAnimation {
        id: enter
        target: win
        property: "shown"
        from: 0
        to: 1
        duration: Theme.animationMs
        easing.type: Easing.OutCubic
    }

    Component.onCompleted: {
        enter.start();
        Qt.callLater(() => card.focusField());
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Theme.dark ? 0.42 : 0.26)
        opacity: win.shown

        MouseArea {
            anchors.fill: parent
            onPressed: LauncherService.builtin.close()
        }
    }

    RectangularShadow {
        visible: Theme.shadows
        anchors.fill: card
        radius: card.radius
        blur: 64
        offset.y: 24
        color: Theme.shadow
        opacity: win.shown
    }

    SearchCard {
        id: card
        provider: LauncherService.builtin
        width: Math.min(760, win.width - 80)
        x: (win.width - width) / 2
        y: Math.round(win.height * 0.16)
        opacity: win.shown
        scale: 0.96 + 0.04 * win.shown
    }
}
