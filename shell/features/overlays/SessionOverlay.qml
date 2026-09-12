pragma ComponentBehavior: Bound

// The shell's own session screen, as the design draws it: log out, restart,
// sleep or hibernate, shut down. Opt-in (session.prompt "shell"); Plasma's
// own screen is the default.
//
// Choosing ends the session through Plasma's session manager, exactly as
// Plasma's screen does -- applications are asked to close and one with
// unsaved work can say so -- so this is a different screen asking, not a
// different way of ending. Escape or Cancel leaves everything as it was.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.domain.session
import qs.domain.surfaces
import qs.domain.theme
import qs.domain.windows
import qs.ui.primitives

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
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    BackgroundEffect.blurRegion: win._everything
    readonly property Region _everything: Region { item: scrim }

    readonly property var choices: [
        { id: "logout", label: "Log out", glyph: "logout", act: () => Session.logout() },
        { id: "reboot", label: "Restart", glyph: "restart_alt", act: () => Session.reboot() },
        Session.canHibernate
            ? { id: "hibernate", label: "Hibernate", glyph: "downloading", act: () => Session.hibernate() }
            : { id: "suspend", label: "Sleep", glyph: "bedtime", act: () => Session.suspend() },
        { id: "shutdown", label: "Shut down", glyph: "power_settings_new", act: () => Session.shutdown(), danger: true }
    ]

    // What the screen was opened for picks the first choice under the keys.
    property int current: ({ promptLogout: 0, promptReboot: 1, promptShutDown: 3 })[Surfaces.sessionKind] ?? 3

    function choose(i) {
        const c = win.choices[i];
        Surfaces.closeAll();
        if (c)
            c.act();
    }

    property real shown: 0
    NumberAnimation on shown { from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic; running: true }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.rgba(0.05, 0.04, 0.04, 0.62)
        opacity: win.shown

        MouseArea {
            anchors.fill: parent
            onPressed: Surfaces.closeAll()
        }
    }

    Item {
        anchors.fill: parent
        opacity: win.shown
        scale: 0.96 + 0.04 * win.shown

        focus: true
        Keys.onEscapePressed: Surfaces.closeAll()
        Keys.onLeftPressed: win.current = (win.current + win.choices.length - 1) % win.choices.length
        Keys.onRightPressed: win.current = (win.current + 1) % win.choices.length
        Keys.onReturnPressed: win.choose(win.current)
        Keys.onEnterPressed: win.choose(win.current)
        Component.onCompleted: forceActiveFocus()

        Column {
            anchors.centerIn: parent
            spacing: 44

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                PanelText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "End session"
                    font.pixelSize: 40
                    font.weight: Font.Light
                    color: "#ffffff"
                }

                PanelText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property int open: WindowsService.windows.length
                    text: open > 0 ? `${open} window${open === 1 ? "" : "s"} open · applications are asked to save first`
                                   : "Applications are asked to save first"
                    font.pixelSize: 15
                    color: Qt.rgba(1, 1, 1, 0.62)
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 26

                Repeater {
                    model: win.choices

                    Rectangle {
                        id: tile

                        required property var modelData
                        required property int index
                        readonly property bool current: tile.index === win.current

                        width: 190
                        height: 190
                        radius: 44
                        color: tile.modelData.danger ? Theme.error
                             : tileHover.hovered || tile.current ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)
                        border.width: tile.modelData.danger ? 0 : (tile.current ? 2 : 1)
                        border.color: tile.current ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.18)
                        scale: tile.current ? 1.03 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 16

                            Glyph {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: tile.modelData.glyph
                                size: 44
                                color: tile.modelData.danger ? Theme.errorFg : "#ffffff"
                            }

                            PanelText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                font.pixelSize: 16
                                color: tile.modelData.danger ? Theme.errorFg : "#ffffff"
                            }
                        }

                        HoverHandler {
                            id: tileHover
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: if (hovered) win.current = tile.index
                        }
                        TapHandler { onTapped: win.choose(tile.index) }
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: cancelText.implicitWidth + 48
                height: 40
                radius: 20
                color: cancelHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.28)

                PanelText {
                    id: cancelText
                    anchors.centerIn: parent
                    text: "Cancel · esc"
                    font.pixelSize: 14
                    color: Qt.rgba(1, 1, 1, 0.8)
                }

                HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Surfaces.closeAll() }
            }
        }
    }
}
