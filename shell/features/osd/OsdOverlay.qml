// The OSD surface.
//
// A layer-shell overlay with no exclusive zone: it floats over whatever is on
// screen and reserves nothing, so a volume change never moves a window.
//
// One screen, not one per screen. Plasma shows its OSD on the active screen;
// showing ours on every monitor at once turns a glance into three glances, and
// Quickshell has no notion of which screen is active for a surface nobody
// clicked.

import QtQuick
import Quickshell
import qs.domain.osd
import qs.domain.theme
import qs.ui.primitives

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    visible: OsdService.showing

    anchors {
        left: true
        right: true
        bottom: true
    }
    margins.bottom: Math.round(root.screen.height * 0.12)

    // Reserves nothing: an OSD that pushed maximised windows around for a
    // second and a half would be worse than no OSD.
    exclusiveZone: 0
    implicitHeight: body.implicitHeight + 24
    color: "transparent"

    // Layer-shell surfaces cannot be sized to their content in one dimension
    // only, so the window spans the screen and the visible panel is centred
    // inside it.
    Rectangle {
        id: body

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: Math.max(240, content.implicitWidth + 40)
        implicitHeight: content.implicitHeight + 28
        radius: 12
        color: Theme.panelBackground

        opacity: OsdService.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Column {
            id: content

            anchors.centerIn: parent
            spacing: 10

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                PanelIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 22
                    iconName: OsdService.icon
                    visible: OsdService.icon.length > 0
                }

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: OsdService.showingProgress
                        ? `${Math.round(OsdService.value)}%`
                        : OsdService.text
                    font.pixelSize: 15
                }
            }

            // Drawn only for a value, not for a message: a bar under "Caps
            // Lock on" would be showing a number that does not exist.
            Rectangle {
                visible: OsdService.showingProgress
                width: 200
                height: 4
                radius: 2
                color: Theme.backgroundAlternate

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, OsdService.value / OsdService.maxValue))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent

                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }

            PanelText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: OsdService.showingProgress && OsdService.text.length > 0
                text: OsdService.text
                color: Theme.foregroundInactive
                font.pixelSize: 11
            }
        }
    }
}
