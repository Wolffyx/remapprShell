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

    // Where the place came from, when the shell worked the sunset out itself.
    readonly property var _placeSaid: ({
        geoclue: "where GeoClue says you are",
        cache: "where GeoClue last said you were",
        coordinates: "at the weather's coordinates"
    })

    // Who decided it is day or night, why it was them, and when it changes.
    function _daylightText(): string {
        const a = Daylight.answer;
        if (!Daylight.known)
            return a.why
                ? `Nothing knows when night is: ${a.why}. Set a place in KDE's night time settings, or coordinates under Weather.`
                : "Asking when night is…";
        const now = Daylight.daylight ? "Day" : "Night";
        const until = Daylight.next > 0
            ? ` ${Daylight.daylight ? "Night" : "Day"} comes at ${Qt.formatTime(new Date(Daylight.next), "hh:mm")}.`
            : "";
        if (Daylight.source === "kde")
            return `${now}, by KDE's night time schedule -- the one Night Light and Plasma follow.${until}`;
        const reason = String(a.why ?? "").split(";")[0];
        const place = root._placeSaid[a.location] ?? "where you are";
        return `${now}, by the sun ${place}: ${reason}.${until}`;
    }

    spacing: 12

    SectionLabel { text: "Colour scheme" }

    Row {
        id: modes
        width: parent.width
        spacing: 12

        Repeater {
            model: [
                { id: "auto", label: "Auto", sub: "Day and night" },
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
            if (Daylight.known)
                return `${now}: light by day, dark by night.`;
            const plasma = PlasmaColors.loaded ? `, because Plasma's colour scheme is ${Scheme.isDark(PlasmaColors.background.toString()) ? "dark" : "light"}` : "";
            return PlasmaColors.automaticLookAndFeel
                ? `${now}${plasma}. Plasma switches between its light and dark theme by itself, and the shell follows it.`
                : `${now}${plasma}: nothing says when night is, so the shell follows Plasma's colour scheme.`;
        }
        lineHeight: 1
    }

    // Whose sunset auto follows. Only auto has one, so the rest of the time
    // this is drawn but not offered.
    Column {
        width: parent.width
        spacing: 8
        opacity: Theme.modeSetting === "auto" ? 1 : 0.45
        enabled: Theme.modeSetting === "auto"

        SectionLabel { text: "Day and night from" }

        ConfigSegmented {
            width: parent.width
            values: ["kde", "shell"]
            labels: ["KDE, else the shell", "Always the shell"]
            path: "theme.daylight.source"
            fallback: "kde"
        }

        Hint {
            width: parent.width
            text: root._daylightText()
            lineHeight: 1
        }
    }

    TextButton {
        glyph: "bedtime"
        iconName: "preferences-desktop-display-nightcolor"
        text: "KDE's night time settings"
        onActivated: PlasmaApplets.openSettings("kcm_nighttime")
    }

    TextButton {
        glyph: "routine"
        iconName: "preferences-desktop-theme-global"
        text: "Plasma's global theme settings"
        onActivated: PlasmaApplets.openSettings("kcm_lookandfeel")
    }
}
