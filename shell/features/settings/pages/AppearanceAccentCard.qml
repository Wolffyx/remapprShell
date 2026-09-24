pragma ComponentBehavior: Bound

// Appearance: the accent card -- Plasma's own accent or one of four of the
// shell's, each drawn as the primary colour it would give.
//
// A card of the appearance page, apart from it so the page reads as the list
// of its cards. It writes one configuration key, and needs nothing of the
// page's but a width.

import QtQuick
import qs.domain.config
import qs.domain.theme
import qs.domain.theme.palette
import qs.ui.primitives

Card {
    id: root

    spacing: 12

    SectionLabel { text: "Accent" }

    Row {
        spacing: 16

        Repeater {
            model: [
                { id: "plasma", label: "Plasma" },
                { id: "blue", label: "Blue" },
                { id: "teal", label: "Teal" },
                { id: "magenta", label: "Magenta" },
                { id: "orange", label: "Orange" }
            ]

            Column {
                id: accentChoice

                required property var modelData
                readonly property bool chosen: Theme.accentSetting === accentChoice.modelData.id

                spacing: 6

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 44
                    height: 44
                    radius: 22
                    color: "transparent"
                    border.width: accentChoice.chosen ? 2 : 0
                    border.color: Theme.fg

                    Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: 18
                        color: Scheme.scheme(Scheme.seed(accentChoice.modelData.id, PlasmaColors.accent.toString()), Theme.dark).primary

                        Glyph {
                            anchors.centerIn: parent
                            visible: accentChoice.modelData.id === "plasma"
                            name: "wallpaper"
                            size: 18
                            color: Scheme.scheme(Scheme.seed("plasma", PlasmaColors.accent.toString()), Theme.dark).onPrimary
                        }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: ConfigStore.set("theme.accent", accentChoice.modelData.id) }
                }

                PanelText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: accentChoice.modelData.label
                    font.pixelSize: 12
                    color: accentChoice.chosen ? Theme.fg : Theme.mut
                }
            }
        }
    }

    Hint {
        text: "Plasma is Plasma's own accent colour -- which System Settings can take from the wallpaper. Every other colour here is worked out from the accent, in Material Design's roles."
        lineHeight: 1
    }
}
