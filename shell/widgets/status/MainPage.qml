pragma ComponentBehavior: Bound

// Quick settings' first page: who is signed in and how the machine is, the
// tiles, the levels, the power profiles, and the way to System Settings.

import QtQuick
import Quickshell
import qs.core
import qs.domain.status
import qs.domain.status.icons
import qs.domain.session
import qs.domain.theme
import qs.platform.system
import qs.ui.primitives
import qs.ui.controls

Column {
    id: main

    // The status widget: its `page` is where a chevron goes, and closing its
    // popout is how an action here that opens something else finishes.
    required property var widget

    spacing: 16

    // Who, and the state of the machine: the power profile and the battery on
    // a laptop, the host and how long it has been up on a desktop.
    Item {
        width: parent.width
        height: 44

        Avatar {
            id: avatar
            anchors.verticalCenter: parent.verticalCenter
            size: 40
            source: Session.avatar
            initial: Session.initial
        }

        Column {
            anchors.left: avatar.right
            anchors.leftMargin: 12
            anchors.right: headButtons.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            PanelText {
                width: parent.width
                elide: Text.ElideRight
                text: Session.displayName
                font.pixelSize: 15
                font.weight: Font.Medium
            }

            PanelText {
                width: parent.width
                elide: Text.ElideRight
                font.pixelSize: 12
                color: Theme.mut
                text: PowerStatus.present
                    ? [StatusIcons.profileLabel(PowerStatus.profile), StatusIcons.percent(PowerStatus.level), PowerStatus.timeLabel]
                        .filter(s => s).join(" · ")
                    : [Session.hostName, Session.uptime].filter(s => s).join(" · ")
            }
        }

        Row {
            id: headButtons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            IconButton {
                glyph: "tune"
                iconName: "configure"
                onActivated: {
                    Quickshell.execDetached([Branding.ctlBin, "settings"]);
                    main.widget.closePopout();
                }
            }

            IconButton {
                glyph: "power_settings_new"
                iconName: "system-shutdown"
                onActivated: {
                    main.widget.closePopout();
                    Session.prompt("promptAll");
                }
            }
        }
    }

    TileGrid {
        width: parent.width
        widget: main.widget
    }

    // The levels. Sliders, not a panel of sliders: the popout is already a
    // card, and a card inside it is one more background between the wallpaper
    // and the thing being read.
    Item {
        width: parent.width
        height: levels.implicitHeight + 32

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.out
        }

        Column {
            id: levels
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 12

            // Each level has a page behind it, reached by the chevron at its
            // end: the devices to play through or record from, and a slider
            // per display. The tiles have had that since the design was drawn
            // and the sliders had not, which left the output device pickable
            // only in Plasma's own applet.
            LevelSlider {
                visible: !!AudioStatus.sink
                width: parent.width
                glyph: AudioStatus.glyph
                iconName: AudioStatus.icon
                to: Math.round(AudioStatus.ceilingFor(AudioStatus.volume) * 100)
                value: AudioStatus.volume * 100
                onMoved: v => AudioStatus.setVolume(v / 100)
                onIconActivated: AudioStatus.toggleMute()

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "chevron_right"
                    iconName: "go-next"
                    onActivated: main.widget.page = "volume"
                }
            }

            // Every display powerdevil can dim, at once; the page behind this
            // has a slider per display.
            LevelSlider {
                visible: BrightnessStatus.displays.length > 0
                width: parent.width
                glyph: StatusIcons.brightnessGlyph(BrightnessStatus.level)
                iconName: BrightnessStatus.icon
                from: 1
                value: BrightnessStatus.level * 100
                onMoved: v => BrightnessStatus.setAllPercent(v)

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "chevron_right"
                    iconName: "go-next"
                    // One display and no night light to speak of is a page
                    // with the slider already on this one on it.
                    visible: BrightnessStatus.displays.length > 1
                             || BrightnessStatus.nightState !== "unavailable"
                    onActivated: main.widget.page = "brightness"
                }
            }
        }
    }

    // power-profiles-daemon's profiles, where there is a battery to spare.
    Row {
        visible: PowerStatus.present
        width: parent.width
        spacing: 8

        Repeater {
            model: PowerStatus.present ? PowerStatus.profiles : []

            TextButton {
                required property string modelData
                width: (parent.width - 8 * (PowerStatus.profiles.length - 1)) / PowerStatus.profiles.length
                text: StatusIcons.profileLabel(modelData)
                checked: PowerStatus.profile === modelData
                onActivated: PowerStatus.setProfile(modelData)
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.out
    }

    Item {
        width: parent.width
        height: 34

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: PowerStatus.present
                name: PowerStatus.glyph
                fallback: PowerStatus.icon
                size: 19
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                text: PowerStatus.present ? StatusIcons.percent(PowerStatus.level) : Session.uptime
                font.pixelSize: 13
                color: PowerStatus.present ? Theme.fg : Theme.mut
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                visible: PowerStatus.present && text.length > 0
                text: PowerStatus.timeLabel ? `· ${PowerStatus.timeLabel}` : ""
                font.pixelSize: 13
                color: Theme.mut
            }
        }

        IconButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glyph: "settings"
            iconName: "preferences-system"
            onActivated: {
                Launch.command(["systemsettings"], "systemsettings");
                main.widget.closePopout();
            }
        }
    }
}
