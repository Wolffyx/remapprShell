pragma ComponentBehavior: Bound

// The key sheet: what the keys do on this machine, as the design lays it out.
//
// Read from kglobalshortcutsrc as it is now, so it shows the keys actually
// bound -- whoever bound them -- and leaves out what is not bound at all.
// Plasma's own shortcut settings are a click away for changing them.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.core
import qs.domain.keys
import qs.domain.surfaces
import qs.domain.theme
import qs.platform.kde
import qs.ui.primitives
import qs.ui.controls

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

    property var sections: []

    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")}/kglobalshortcutsrc`
        printErrors: false
        onLoaded: win.sections = KeyMap.sections(KeyMap.parse(text()), Branding.slug)
    }

    property real shown: 0
    NumberAnimation on shown { from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic; running: true }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.03, 0.03, 0.6)
        opacity: win.shown

        MouseArea {
            anchors.fill: parent
            onPressed: Surfaces.closeAll()
        }
    }

    Rectangle {
        id: card

        width: Math.min(980, win.width - 80)
        height: Math.min(content.implicitHeight + 68, win.height - 80)
        anchors.centerIn: parent
        radius: Theme.radius
        color: Theme.glass
        border.width: 1
        border.color: Theme.out
        opacity: win.shown
        scale: 0.96 + 0.04 * win.shown

        focus: true
        Keys.onEscapePressed: Surfaces.closeAll()
        Component.onCompleted: forceActiveFocus()

        MouseArea { anchors.fill: parent }

        Column {
            id: content
            x: 38
            y: 34
            width: parent.width - 76
            spacing: 24

            Item {
                width: parent.width
                height: 34

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    PanelText {
                        anchors.baseline: hint.baseline
                        text: "Keyboard"
                        font.pixelSize: 24
                        font.weight: Font.Medium
                    }

                    PanelText {
                        id: hint
                        text: "What the keys do here · esc to dismiss"
                        font.pixelSize: 13
                        color: Theme.mut
                    }
                }

                TextButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "keyboard"
                    iconName: "preferences-desktop-keyboard-shortcut"
                    text: "Change them…"
                    onActivated: {
                        PlasmaApplets.openSettings("kcm_keys");
                        Surfaces.closeAll();
                    }
                }
            }

            PanelText {
                visible: win.sections.length === 0
                text: "No global shortcuts are bound."
                color: Theme.mut
            }

            Row {
                width: parent.width
                spacing: 28

                Repeater {
                    model: win.sections

                    Column {
                        id: section
                        required property var modelData
                        width: (content.width - 28 * (win.sections.length - 1)) / Math.max(1, win.sections.length)
                        spacing: 12

                        SectionLabel { text: section.modelData.title }

                        Repeater {
                            model: section.modelData.rows

                            Row {
                                id: line
                                required property var modelData
                                spacing: 12

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(150, keysText.implicitWidth + 18)
                                    height: 26
                                    radius: 7
                                    color: Theme.s2

                                    PanelText {
                                        id: keysText
                                        x: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: line.modelData.keys.join("  ·  ")
                                        font.family: Theme.monoFamily
                                        font.pixelSize: 12
                                    }
                                }

                                PanelText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: section.width - 170
                                    elide: Text.ElideRight
                                    text: line.modelData.label
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
