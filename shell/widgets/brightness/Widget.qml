pragma ComponentBehavior: Bound

// Screen brightness and Night Light.
//
// powerdevil owns the brightness and KWin owns Night Light; this shows both
// and changes both. Plasma keeps its brightness applet inside the system
// tray, so under our renderer the panel had no way to dim an external
// monitor or hold Night Light off for a film. The keys worked all along --
// powerdevil handles them itself -- and still do.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.platform.kde
import qs.ui.controls
import qs.ui.primitives

BarWidget {
    id: root

    readonly property int step: root.widgetConfig?.step ?? 5
    readonly property string nightState: BrightnessStatus.nightState
    readonly property bool nightSwitchable: ["warm", "day", "suspended"].includes(root.nightState)

    present: BrightnessStatus.present
    wantsWheel: BrightnessStatus.displays.length > 0

    tooltip: BrightnessStatus.displays
        .map(d => `${d.label || d.name}: ${StatusIcons.percent(d.brightness / d.max)}`)
        .concat(root.nightState === "unavailable" ? [] : [StatusIcons.nightLightLabel(BrightnessStatus.nightLight)])
        .join("\n")

    implicitWidth: 24
    implicitHeight: 24

    function handleWheel(delta) {
        BrightnessStatus.step(delta, root.step);
    }

    function handleActivate(button) {
        if (button === Qt.MiddleButton) {
            BrightnessStatus.toggleNightLight();
            return;
        }
        root.popoutVisible = !root.popoutVisible;
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: (hover.hovered || root.popoutVisible) ? Theme.hoverBackground : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        PanelIcon {
            anchors.centerIn: parent
            implicitSize: 18
            iconName: BrightnessStatus.icon
        }

        HoverHandler { id: hover }
    }

    popout: Component {
        Item {
            implicitWidth: 320
            implicitHeight: body.implicitHeight

            Column {
                id: body
                width: parent.width
                spacing: 10

                // Keyed by name, so a value moving does not rebuild the row
                // whose slider is being dragged.
                Repeater {
                    model: JSON.parse(BrightnessStatus.displayNames)

                    Column {
                        id: screen

                        required property string modelData
                        readonly property var display: BrightnessStatus.displays.find(d => d.name === screen.modelData)
                                                       ?? { label: "", brightness: 0, max: 1 }

                        width: body.width
                        spacing: 2

                        PanelText {
                            width: parent.width
                            text: screen.display.label || screen.modelData
                            elide: Text.ElideRight
                            color: Theme.foregroundInactive
                            font.pixelSize: 11
                        }

                        Row {
                            width: parent.width
                            spacing: 6

                            PanelIcon {
                                id: glyph
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 22
                                iconName: StatusIcons.brightnessIcon(screen.display.brightness / screen.display.max)
                            }

                            NumberSlider {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - glyph.width - parent.spacing
                                live: true
                                from: 1
                                to: 100
                                value: screen.display.brightness / screen.display.max * 100
                                onMoved: v => BrightnessStatus.setBrightness(screen.modelData,
                                    Math.max(StatusIcons.brightnessFloor(screen.display.max),
                                             Math.round(v * screen.display.max / 100)))
                            }
                        }
                    }
                }

                Row {
                    visible: root.nightState !== "unavailable"
                    width: parent.width
                    spacing: 10

                    PanelIcon {
                        id: nightGlyph
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 22
                        iconName: StatusIcons.nightLightIcon(root.nightState)
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - nightGlyph.width - nightSwitch.width - 2 * parent.spacing
                        spacing: 1

                        PanelText {
                            width: parent.width
                            text: StatusIcons.nightLightLabel(BrightnessStatus.nightLight)
                            elide: Text.ElideRight
                        }

                        PanelText {
                            visible: text.length > 0
                            width: parent.width
                            text: BrightnessStatus.nightDetail
                            elide: Text.ElideRight
                            color: Theme.foregroundInactive
                            font.pixelSize: 11
                        }
                    }

                    Toggle {
                        id: nightSwitch
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: root.nightSwitchable
                        opacity: enabled ? 1 : 0.4
                        checked: root.nightState === "warm" || root.nightState === "day"
                        onToggled: BrightnessStatus.toggleNightLight()
                    }
                }

                Row {
                    spacing: 6

                    TextButton {
                        visible: root.nightState !== "unavailable"
                        text: "Night Light settings…"
                        iconName: "redshift-status-on"
                        onActivated: {
                            PlasmaApplets.openSettings("kcm_nightlight");
                            root.popoutVisible = false;
                        }
                    }

                    TextButton {
                        text: "…"
                        iconName: "brightness-high"
                        onActivated: {
                            PlasmaApplets.open("org.kde.plasma.brightness");
                            root.popoutVisible = false;
                        }
                    }
                }
            }
        }
    }
}
