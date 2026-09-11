// The start button.
//
// It knows nothing about which launcher will open -- that is
// LauncherService's decision, made from configuration. Adding a provider never
// touches this file.

import QtQuick
import qs.ui.primitives
import qs.domain.theme
import qs.domain.launcher

BarWidget {
    id: root

    readonly property string iconName: root.widgetConfig?.icon ?? "start-here-kde"
    readonly property string labelText: root.widgetConfig?.label ?? ""

    wantsHover: true

    // A button with a label has already said what it is.
    tooltip: root.labelText.length > 0 ? "" : "Applications"

    // The built-in launcher draws in one of our own windows, so it gets a
    // popout anchored to this button. Every other provider is its own process
    // and positions itself, so there is nothing to anchor.
    popout: LauncherService.active.embedded ? popoutComponent : null

    readonly property Component popoutComponent: Component {
        LauncherPanel {}
    }

    popoutVisible: LauncherService.active.visible
                   && LauncherService.active.embedded
                   && LauncherService.builtin.shownOn === root.screenName

    // The built-in launcher is a search field; it is useless without the
    // keyboard.
    popoutGrabsFocus: true

    implicitWidth: content.implicitWidth + 12
    implicitHeight: 26

    function handleActivate(button) {
        // Tell the provider which screen this button is on, so the popout is
        // built there and only there.
        if (LauncherService.active === LauncherService.builtin && !LauncherService.builtin.visible)
            LauncherService.builtin.openOn(root.screenName, "apps");
        else
            LauncherService.toggle("apps");
    }

    Rectangle {
        anchors.fill: parent
        radius: 5
        color: LauncherService.active.visible ? Theme.pressedBackground
             : hover.hovered ? Theme.hoverBackground
             : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 6

            PanelIcon {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 18
                iconName: root.iconName
                fallbackName: "application-x-executable"
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                // Icon only down the side of the screen, where a word would be
                // wider than the panel.
                visible: root.labelText.length > 0 && (root.bar?.horizontal ?? true)
                text: root.labelText
            }
        }

        HoverHandler { id: hover }
    }
}
