pragma ComponentBehavior: Bound

// Quick settings' brightness page: a slider per display, and Night Light.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.platform.kde
import qs.ui.primitives
import qs.ui.controls

Column {
    id: brightness

    // The status widget: its `page` is where the header goes back to.
    required property var widget

    spacing: 12

    PageHeader {
        widget: brightness.widget
        title: "Brightness"
        switchable: false
    }

    PanelText {
        visible: BrightnessStatus.displays.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.mut
        font.pixelSize: 12
        leftPadding: 4
        text: "No display powerdevil can dim."
    }

    // One slider per display, rather than the one on the first page that
    // moves all of them together.
    Column {
        width: parent.width
        spacing: 10

        // Keyed by name, as the brightness widget's are: every step of a drag
        // replaces the list of displays, and a Repeater over the list itself
        // rebuilt the row -- and the slider -- being dragged.
        Repeater {
            model: JSON.parse(BrightnessStatus.displayNames)

            Column {
                id: screen

                required property string modelData
                readonly property var display: BrightnessStatus.displayNamed(screen.modelData)
                                               ?? { label: "", brightness: 0, max: 1 }

                width: parent.width
                spacing: 2

                // powerdevil's own name for a display ("display0") is an id,
                // not a name anybody chose; its label is the monitor's own, as
                // the manufacturer wrote it. The brightness widget has always
                // shown the label and this page showed the id instead.
                PanelText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: screen.display.label || screen.modelData
                    font.pixelSize: 12
                    color: Theme.mut
                    leftPadding: 4
                }

                LevelSlider {
                    width: parent.width
                    glyph: StatusIcons.brightnessGlyph((screen.display.brightness ?? 0) / Math.max(1, screen.display.max))
                    from: 1
                    value: 100 * (screen.display.brightness ?? 0) / Math.max(1, screen.display.max)
                    onMoved: v => BrightnessStatus.setPercent(screen.modelData, v)
                }
            }
        }
    }

    Rectangle {
        visible: BrightnessStatus.nightState !== "unavailable"
        width: parent.width
        height: 1
        color: Theme.out
    }

    // Said the way the brightness widget says it -- the state in words, and
    // when it next changes -- rather than in wording of this page's own. Two
    // screens describing one thing differently is how a reader ends up
    // believing they are two things.
    ToggleRow {
        visible: BrightnessStatus.nightState !== "unavailable"
        width: parent.width
        label: StatusIcons.nightLightLabel(BrightnessStatus.nightLight)
        description: BrightnessStatus.nightState === "off"
            ? "Off in System Settings, which is the only place that turns it on."
            : BrightnessStatus.nightDetail
        enabled: BrightnessStatus.nightState !== "off"
        checked: BrightnessStatus.nightState === "warm" || BrightnessStatus.nightState === "day"
        onToggled: BrightnessStatus.toggleNightLight()
    }

    TextButton {
        glyph: "display_settings"
        iconName: "preferences-desktop-display"
        text: "Display settings…"
        onActivated: {
            PlasmaApplets.openSettings("kcm_kscreen");
            brightness.widget.closePopout();
        }
    }
}
