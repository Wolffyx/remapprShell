pragma ComponentBehavior: Bound

// The window being worked in, on this screen.
//
// KWin has one active window for the whole desktop. A panel per monitor that
// each named it would say the same thing twice and nothing about the other
// screen, so each names the window last active on its own monitor -- the
// active one, wherever it is -- which is what a tiling desktop's bars do. On
// the monitor without the focus the title is dimmed, and a click brings that
// window forward.

import QtQuick
import qs.domain.theme
import qs.domain.windows
import qs.domain.windows.events
import qs.ui.primitives

BarWidget {
    id: root

    readonly property int maxWidth: root.widgetConfig?.maxWidth ?? 320
    readonly property bool showIcon: root.widgetConfig?.showIcon ?? true
    readonly property bool showAppName: root.widgetConfig?.showAppName ?? false

    readonly property var window: WindowsService.windowFor(root.screenName)
    readonly property string appName: root.window ? WindowsService.appNameFor(root.window) : ""
    readonly property string title: root.window ? WindowEvents.label(root.window) : ""

    // Clicks and hover come through the panel, as for the other widgets with
    // no popout.
    wantsHover: true
    property bool pointed: false

    present: root.window !== null

    tooltip: root.appName && root.appName !== root.title ? `${root.title}\n${root.appName}` : root.title

    implicitWidth: row.implicitWidth + 2 * Math.round(12 * Math.max(0.7, root.unit))
    implicitHeight: root.tileSize

    function handleHover(position, horizontal) {
        root.pointed = true;
    }

    onDismissPopout: root.pointed = false

    function handleActivate(button) {
        if (button === Qt.MiddleButton || !root.window)
            return;
        WindowsService.activate(root.window.uuid);
    }

    BarButton {
        anchors.fill: parent
        thickness: root.barThickness
        hovered: root.pointed
        size: root.tileSize
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        PanelIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showIcon
            implicitSize: Math.max(16, Math.round(22 * root.unit))
            iconName: root.window ? WindowsService.iconFor(root.window) : ""
            iconFile: root.window ? WindowsService.iconFileFor(root.window) : ""
        }

        PanelText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(label.implicitWidth, root.maxWidth)
            elide: Text.ElideRight
            text: root.showAppName ? root.appName : root.title
            color: root.window?.active ? Theme.fg : Theme.mut
        }
    }
}
