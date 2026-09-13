import QtQuick
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Rectangle {
    color: Theme.surfaceDim

    Column {
        x: 24; y: 24
        spacing: 16
        width: 560

        PanelText { text: `Meridian controls · ${Theme.mode} · seed ${Theme.seed} · font ${Theme.fontFamily} · icons ${Theme.hasIconFont}`; font.pixelSize: 15 }

        Rectangle {
            width: parent.width; height: 360; radius: Theme.radius; color: Theme.glass
            border.width: 1; border.color: Theme.out
            Column {
                x: 20; y: 20; spacing: 12; width: parent.width - 40
                Row { spacing: 12
                    Toggle { checked: true }
                    Toggle { checked: false }
                    TextButton { text: "Balanced"; checked: true }
                    TextButton { text: "Power saver" }
                    TextButton { text: "Lock now"; primary: true; glyph: "lock" }
                }
                NumberSlider { width: parent.width; value: 62; to: 100 }
                Row { spacing: 8
                    IconButton { glyph: "tune" }
                    IconButton { glyph: "power_settings_new" }
                    Glyph { name: "wifi"; size: 22 }
                    Glyph { name: "bluetooth"; size: 22 }
                    Glyph { name: "volume_up"; size: 22 }
                    Glyph { name: "battery_5_bar"; size: 22 }
                    Glyph { name: "notifications"; size: 22; color: Theme.acc }
                }
                Select { values: ["auto", "light", "dark"]; currentIndex: 0; width: 200 }
                TextInputRow { width: 300; text: "hello" }
                SettingRow { width: parent.width; label: "Translucent surfaces"; description: "The panel lets a little of the wallpaper through."; overridden: true; Toggle { checked: true } }
            }
        }

        Flow {
            width: parent.width; spacing: 6
            Repeater {
                model: ["primary","primaryContainer","surface","surfaceContainerLow","surfaceContainer","surfaceContainerHigh","surfaceContainerHighest","surfaceFg","surfaceVariantFg","outline","outlineVariant","error","positive","warning"]
                Rectangle { required property string modelData; width: 72; height: 40; radius: 8; color: Theme[modelData]; border.width: 1; border.color: Theme.out
                    Text { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 3; text: parent.modelData.replace("surfaceContainer","sC"); font.pixelSize: 8; color: Theme.dark ? "white" : "black" } }
            }
        }
    }
}
