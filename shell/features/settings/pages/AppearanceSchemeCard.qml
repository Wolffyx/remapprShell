pragma ComponentBehavior: Bound

// Appearance: the colour scheme card -- light, dark, or whichever Plasma is
// in -- each choice drawn in its own colours, with what the shell is now and
// why.
//
// A card of the appearance page, apart from it because it is a picture as
// much as a control and the page is easier to read as the list of its cards.
// It writes one configuration key, and needs nothing of the page's: the page
// gives it a width, as it gives every card.

import QtQuick
import qs.platform.kde
import qs.domain.config
import qs.domain.theme
import qs.domain.theme.palette
import qs.ui.primitives
import qs.ui.controls

Card {
    id: root

    spacing: 12

    SectionLabel { text: "Colour scheme" }

    Row {
        id: modes
        width: parent.width
        spacing: 12

        Repeater {
            model: [
                { id: "auto", label: "Auto", sub: "Follows Plasma" },
                { id: "light", label: "Light", sub: "Always light" },
                { id: "dark", label: "Dark", sub: "Always dark" }
            ]

            Rectangle {
                id: modeCard

                required property var modelData
                readonly property bool chosen: Theme.modeSetting === modeCard.modelData.id
                readonly property var light: Scheme.scheme(Theme.seed, false)
                readonly property var dark: Scheme.scheme(Theme.seed, true)

                width: (modes.width - 2 * modes.spacing) / 3
                height: 112
                radius: Theme.radiusSmall + 2
                color: modeCard.chosen ? Theme.accC : (modeHover.hovered ? Theme.s3 : Theme.s2)
                border.width: 1
                border.color: modeCard.chosen ? Theme.acc : Theme.out

                // A picture of the scheme, in the scheme's own colours: the
                // automatic one is half of each.
                Rectangle {
                    id: swatch
                    x: 14; y: 14
                    width: parent.width - 28
                    height: 50
                    radius: 10
                    clip: true
                    color: "transparent"

                    Row {
                        anchors.fill: parent

                        Repeater {
                            model: modeCard.modelData.id === "auto" ? [modeCard.light, modeCard.dark]
                                 : [modeCard.modelData.id === "dark" ? modeCard.dark : modeCard.light]

                            Rectangle {
                                id: half

                                required property var modelData

                                width: swatch.width / (modeCard.modelData.id === "auto" ? 2 : 1)
                                height: swatch.height
                                color: half.modelData.surfaceContainerLow

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Rectangle { width: 22; height: 22; radius: 11; color: half.modelData.primary }
                                    Rectangle { width: 38; height: 22; radius: 11; color: half.modelData.surfaceContainerHighest }
                                }
                            }
                        }
                    }
                }

                Column {
                    x: 14
                    anchors.top: swatch.bottom
                    anchors.topMargin: 10
                    spacing: 1

                    PanelText {
                        text: modeCard.modelData.label
                        font.pixelSize: 14
                        color: modeCard.chosen ? Theme.accCFg : Theme.fg
                    }
                    PanelText {
                        text: modeCard.modelData.sub
                        font.pixelSize: 12
                        color: modeCard.chosen ? Theme.accCFg : Theme.mut
                    }
                }

                HoverHandler { id: modeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: ConfigStore.set("theme.mode", modeCard.modelData.id) }
            }
        }
    }

    Hint {
        text: {
            const now = `The shell is ${Theme.mode} now`;
            if (Theme.modeSetting !== "auto")
                return `${now}, whatever Plasma does.`;
            const plasma = PlasmaColors.loaded ? `, because Plasma's colour scheme is ${Scheme.isDark(PlasmaColors.background.toString()) ? "dark" : "light"}` : "";
            return PlasmaColors.automaticLookAndFeel
                ? `${now}${plasma}. Plasma switches between its light and dark theme by itself, and the shell follows it.`
                : `${now}${plasma}. Plasma can also switch between a light and a dark theme by itself at sunset, and the shell will follow it: that is in Plasma's global theme settings.`;
        }
        lineHeight: 1
    }

    TextButton {
        glyph: "routine"
        iconName: "preferences-desktop-theme-global"
        text: "Plasma's global theme settings"
        onActivated: PlasmaApplets.openSettings("kcm_lookandfeel")
    }
}
