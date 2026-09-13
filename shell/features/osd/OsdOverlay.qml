// The OSD surface.
//
// A layer-shell overlay with no exclusive zone: it floats over whatever is on
// screen and reserves nothing, so a volume change never moves a window. It
// takes no input either -- it is a glance, and a click on what is beneath it
// must land.
//
// One screen, not one per screen. Plasma shows its OSD on the active screen;
// showing ours on every monitor at once turns a glance into three glances, and
// Quickshell has no notion of which screen is active for a surface nobody
// clicked.

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.domain.osd
import qs.domain.status.icons
import qs.domain.theme
import qs.ui.primitives

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    visible: OsdService.showing || body.opacity > 0

    anchors {
        left: true
        right: true
        bottom: true
    }
    margins.bottom: Math.round(root.screen.height * 0.12)

    // Reserves nothing: an OSD that pushed maximised windows around for a
    // second and a half would be worse than no OSD.
    exclusiveZone: 0
    mask: Region {}
    implicitHeight: body.implicitHeight + 64
    color: "transparent"

    readonly property real fraction: OsdService.maxValue > 0
        ? Math.max(0, Math.min(1, OsdService.value / OsdService.maxValue)) : 0
    readonly property string glyph: StatusIcons.osdGlyph(OsdService.icon, root.fraction)

    RectangularShadow {
        visible: Theme.shadows
        anchors.fill: body
        radius: body.radius
        blur: 36
        offset.y: 10
        color: Theme.shadow
        opacity: body.opacity
    }

    // Layer-shell surfaces cannot be sized to their content in one dimension
    // only, so the window spans the screen and the pill is centred inside it.
    Rectangle {
        id: body

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: content.implicitWidth + 52
        implicitHeight: content.implicitHeight + 32
        radius: Math.min(Theme.radius, height / 2)
        color: Theme.glass
        border.width: 1
        border.color: Theme.out

        opacity: OsdService.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        transform: Translate { y: OsdService.showing ? 0 : 10; Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 18

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30

                Glyph {
                    anchors.centerIn: parent
                    visible: root.glyph.length > 0
                    name: root.glyph
                    size: 30
                    color: Theme.acc
                }

                PanelIcon {
                    anchors.centerIn: parent
                    visible: root.glyph.length === 0 && OsdService.icon.length > 0
                    implicitSize: 26
                    iconName: OsdService.icon
                }
            }

            // A level: the bar and its number, with any words beside them.
            Row {
                visible: OsdService.showingProgress
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 260
                    height: 10
                    radius: 5
                    color: Theme.alpha(Theme.fg, 0.12)

                    Rectangle {
                        width: parent.width * root.fraction
                        height: parent.height
                        radius: parent.radius
                        color: Theme.acc
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }
                }

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    text: `${Math.round(OsdService.value)}`
                    font.family: Theme.monoFamily
                    font.pixelSize: 18
                }
            }

            // A message, and nothing to measure: no bar.
            PanelText {
                visible: !OsdService.showingProgress || OsdService.text.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: OsdService.text
                font.pixelSize: OsdService.showingProgress ? 13 : 16
                color: OsdService.showingProgress ? Theme.mut : Theme.fg
            }
        }
    }
}
