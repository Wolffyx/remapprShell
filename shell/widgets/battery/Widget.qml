pragma ComponentBehavior: Bound

// The battery, and the power profile.
//
// UPower owns the battery and power-profiles-daemon owns the profile; this
// shows the one and switches the other. Absent on a machine with no battery,
// which is what makes it safe in a preset shared by laptops and desktops.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.platform.kde
import qs.ui.controls
import qs.ui.primitives

BarWidget {
    id: root

    readonly property bool showPercentage: root.widgetConfig?.showPercentage ?? false

    present: PowerStatus.present

    tooltip: [StatusIcons.percent(PowerStatus.level), PowerStatus.stateLabel, PowerStatus.timeLabel]
        .filter(s => s).join(" · ")

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function handleActivate(button) {
        root.popoutVisible = !root.popoutVisible;
    }

    BarButton {
        id: button
        thickness: root.barThickness
        vertical: root.barVertical
        hovered: root.hovered
        active: root.popoutVisible
        size: root.tileSize
        glyph: PowerStatus.glyph
        fallback: PowerStatus.icon
        glyphSize: root.panelIconSize
        text: root.showPercentage ? StatusIcons.percent(PowerStatus.level) : ""
    }

    popout: Component {
        Item {
            implicitWidth: 280
            implicitHeight: body.implicitHeight

            Column {
                id: body
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 10

                    PanelIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 32
                        iconName: PowerStatus.icon
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        PanelText {
                            text: StatusIcons.percent(PowerStatus.level)
                            font.bold: true
                            font.pixelSize: 16
                        }

                        PanelText {
                            text: [PowerStatus.stateLabel, PowerStatus.timeLabel].filter(s => s).join(" · ")
                            color: Theme.foregroundInactive
                            font.pixelSize: 11
                        }
                    }
                }

                PanelText {
                    text: "Power profile"
                    font.bold: true
                    font.pixelSize: 11
                }

                Row {
                    spacing: 6

                    Repeater {
                        model: PowerStatus.profiles

                        TextButton {
                            required property string modelData
                            text: StatusIcons.profileLabel(modelData)
                            iconName: StatusIcons.profileIcon(modelData)
                            checked: PowerStatus.profile === modelData
                            onActivated: PowerStatus.setProfile(modelData)
                        }
                    }
                }

                TextButton {
                    text: "Power and battery…"
                    iconName: "battery-good"
                    onActivated: {
                        PlasmaApplets.open("org.kde.plasma.battery");
                        root.popoutVisible = false;
                    }
                }
            }
        }
    }
}
