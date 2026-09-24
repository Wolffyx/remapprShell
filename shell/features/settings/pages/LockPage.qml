pragma ComponentBehavior: Bound

// Lock & session: what happens when the screen locks, and what the power
// button offers.
//
// The lock screen is the one part of this project that can leave someone
// unable to get back into their own session, so it is off until it has been
// tried: `try` shows it in Plasma's real greeter and only a password that
// actually unlocks records the attempt. This page runs the same commands the
// CLI does and refuses nothing on its own -- the gates are in the script.

import QtQuick
import qs.platform.kde
import qs.platform.system
import qs.domain.session
import qs.domain.surfaces
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    // `lockscreen status --json`, and the command that changes it.
    readonly property CtlSession ctl: CtlSession {
        prefix: ["lockscreen"]
        readFailed: "Could not read the lock screen's state."
    }
    readonly property var info: root.ctl.state

    readonly property bool installed: root.info?.enabled === true
    // What `enable` itself requires: this exact build, unlocked in this
    // greeter. A build that was tried before the last edit -- or before a
    // kscreenlocker update -- does not count, and the script refuses it.
    readonly property bool tried: (root.info?.tried ?? null) !== null
    // The look, as `lockscreen status --json` reports it: these are keys in
    // the greeter's own config group, because the greeter cannot read this
    // shell's configuration at all.
    readonly property var look: root.info?.look ?? []
    function lookValue(id, fallback) { return (root.look.find(l => l.id === id)?.value) ?? fallback; }
    function lookBool(id) { return String(root.lookValue(id, "false")) === "true"; }

    readonly property bool ready: root.info?.triedIsSource === true && root.info?.triedWithThisGreeter === true

    spacing: 14

    Component.onCompleted: root.ctl.refresh()

    PanelText {
        visible: root.ctl.status.length > 0
        width: root.width
        wrapMode: Text.WordWrap
        text: root.ctl.status
        font.pixelSize: 12
        color: Theme.error
    }

    Card {
        width: root.width

        SectionLabel { text: "Lock screen" }

        Item {
            width: parent.width
            height: 22

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.installed ? "This shell's lock screen is on"
                                   : "Plasma's lock screen is what you get"
                font.pixelSize: 14
            }

            PanelText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.ready ? "tried" : (root.tried ? "changed since it was tried" : "never tried")
                font.pixelSize: 12
                color: root.ready ? Theme.acc : Theme.mut
            }
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Plasma's greeter does the locking either way; only the drawing would be this shell's. Try it first: it fills every screen and takes the keyboard, exactly as a real lock does, but nothing is locked and typing your password ends it. Turning it on before it has unlocked once is refused."
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
        }

        Row {
            spacing: 8

            TextButton {
                glyph: "play_circle"
                iconName: "media-playback-start"
                text: "Try it…"
                enabled: !root.ctl.busy
                onActivated: root.ctl.run(["try"])
            }

            TextButton {
                visible: !root.installed
                primary: root.ready
                glyph: "lock"
                iconName: "lock"
                text: "Turn it on"
                enabled: !root.ctl.busy && root.ready
                onActivated: root.ctl.run(["enable"])
            }

            TextButton {
                visible: root.installed
                glyph: "lock_open"
                iconName: "unlock"
                text: "Turn it off"
                enabled: !root.ctl.busy
                onActivated: root.ctl.run(["disable"])
            }
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: root.installed
            text: "The way back, from a text console (Ctrl+Alt+F3): loginctl unlock-session, then `rmpr lockscreen disable`."
            font.family: Theme.monoFamily
            font.pixelSize: 12
            color: Theme.mut
        }
    }

    Card {
        width: root.width
        opacity: root.installed ? 1 : 0.7

        SectionLabel { text: "How it looks" }

        PanelText {
            width: parent.width
            visible: !root.installed
            wrapMode: Text.WordWrap
            text: "Saved now, and drawn when this lock screen is turned on."
            font.pixelSize: 12
            color: Theme.mut
        }

        // Twelve lock screens, not twelve colour schemes: they differ on where
        // the password lives, how much wallpaper survives and how loud the
        // type is. A dropdown would hide exactly that, so each is a row with
        // the sentence that tells them apart.
        Column {
            width: parent.width
            spacing: 6

            Repeater {
                model: [
                    { id: "glass",     name: "Glass",           about: "The one this shell shipped with: a blurred wallpaper, a frosted column, the clock rising out of the way." },
                    { id: "editorial", name: "Editorial split",  about: "An opaque panel owns the password; the wallpaper stays sharp beside it, unblurred." },
                    { id: "console",   name: "Console",          about: "No wallpaper and no glass. A tty prompt, all monospace, where the keys are the whole interface." },
                    { id: "ambient",   name: "Ambient",          about: "The wallpaper unblurred under a light veil, dark type over it, one hairline field." },
                    { id: "board",     name: "Widget board",     about: "A grid of cards to read in one glance, with the password as the bar along the foot." },
                    { id: "poster",    name: "Poster",           about: "The picture is the design. One strip at the foot carries the time, the password and the status." },
                    { id: "seats",     name: "Multi-user",       about: "A card for every session on the machine: unlock this one, or click another seat to switch to it." },
                    { id: "minimal",   name: "Minimal",          about: "The clock and nothing else. The field fades in when you type and out when you stop; light or dark follows the desktop." },
                    { id: "dayahead",  name: "Day ahead",        about: "A palette that follows the time of day, from dawn to night, with the day laid out as a ruler under the clock." },
                    { id: "secure",    name: "Secure workstation", about: "Monospace and auditable: the ways PAM will let you in, and a live log of everything that happened at this lock." },
                    { id: "accessible", name: "Accessible",      about: "Large type, high contrast, the on-screen keyboard and captions of what the screen says, all on the screen rather than in a menu." },
                    { id: "kiosk",     name: "Kiosk",            about: "For a shared computer: one big button to a guest session, a notice of your own, and the owner's sign-in in a corner." },
                ]

                Rectangle {
                    id: styleRow

                    required property var modelData
                    readonly property bool current: root.lookValue("style", "glass") === styleRow.modelData.id

                    width: parent.width
                    height: styleText.height + 22
                    radius: Theme.radiusOf(12)
                    color: styleRow.current ? Theme.secondaryContainer
                                            : (styleHover.hovered ? Theme.hover : Theme.s1)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: "transparent"
                            border.width: styleRow.current ? 5 : 1.5
                            border.color: styleRow.current ? Theme.acc : Theme.out
                        }

                        Column {
                            id: styleText

                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 28
                            spacing: 2

                            PanelText {
                                text: styleRow.modelData.name
                                font.pixelSize: 14
                                color: styleRow.current ? Theme.secondaryContainerFg : Theme.fg
                            }

                            PanelText {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: styleRow.modelData.about
                                font.pixelSize: 12
                                lineHeight: 1.3
                                color: styleRow.current ? Theme.secondaryContainerFg : Theme.mut
                            }
                        }
                    }

                    HoverHandler { id: styleHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.ctl.run(["set", "style", styleRow.modelData.id]) }
                    Accessible.name: styleRow.modelData.name
                }
            }
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: root.installed
            text: "A style changes at the next lock. The one that was tried is the one that is installed, so a style picked here is drawn without trying it again -- the password is taken the same way in all seven."
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
        }

        SettingRow {
            width: parent.width
            // Only Glass has room on both sides for the clock to move.
            visible: root.lookValue("style", "glass") === "glass"
            label: "The clock"

            Segmented {
                width: parent.width
                values: ["left", "center"]
                labels: ["Left", "Centred"]
                current: root.lookValue("clock", "left")
                onPicked: value => root.ctl.run(["set", "clock", value])
            }
        }

        SettingRow {
            width: parent.width
            // Only the kiosk says anything about whose computer it is.
            visible: root.lookValue("style", "glass") === "kiosk"
            label: "The kiosk's name"
            description: "Drawn at the top, where a guest looks first. Empty says \"Shared computer\"."

            TextInputRow {
                width: parent.width
                text: root.lookValue("kioskName", "")
                onCommitted: value => root.ctl.run(["set", "kioskName", value])
            }
        }

        SettingRow {
            width: parent.width
            visible: root.lookValue("style", "glass") === "kiosk"
            label: "A notice for guests"
            description: "One line, shown where a guest will read it. Empty shows nothing."

            TextInputRow {
                width: parent.width
                text: root.lookValue("kioskNote", "")
                onCommitted: value => root.ctl.run(["set", "kioskNote", value])
            }
        }

        SettingRow {
            width: parent.width
            label: "Accent"
            description: "The focus ring, the caret and the primary button, on every style."

            Segmented {
                width: parent.width
                values: ["indigo", "terracotta", "green", "violet"]
                labels: ["Indigo", "Terracotta", "Green", "Violet"]
                current: root.lookValue("accent", "indigo")
                onPicked: value => root.ctl.run(["set", "accent", value])
            }
        }

        SliderRow {
            // Half of the twelve leave the wallpaper alone on purpose, and
            // most of those draw over it entirely.
            visible: ["glass", "board"].includes(root.lookValue("style", "glass"))
            label: "Wallpaper blur behind the prompt"
            from: 0
            to: 40
            stepSize: 2
            value: Number(root.lookValue("blur", 26))
            onMoved: value => root.ctl.run(["set", "blur", Math.round(value)])
        }

        ToggleRow {
            label: "Show the clock while nothing is happening"
            description: "Off, the screen is dark until a key or the pointer wakes the prompt."
            checked: root.lookBool("idleClock")
            onToggled: value => root.ctl.run(["set", "idleClock", value])
        }

        SettingRow {
            width: parent.width
            label: "Dim to the clock after"
            description: "With nobody at it, the screen goes dark but for the clock. Plasma still turns the screen off on its own schedule."

            Segmented {
                width: parent.width
                values: ["0", "10", "20", "60", "300"]
                labels: ["Never", "10 s", "20 s", "1 min", "5 min"]
                current: String(root.lookValue("dim", "20"))
                onPicked: value => root.ctl.run(["set", "dim", value])
            }
        }

        ToggleRow {
            label: "Lift the shutter when unlocking"
            description: "The lock screen slides away over the unblurring wallpaper. Off, it goes at once, as Plasma's does."
            checked: root.lookBool("unlockAnimation")
            onToggled: value => root.ctl.run(["set", "unlockAnimation", value])
        }

        SettingRow {
            width: parent.width
            label: "On a battery about to run out"
            description: "At Plasma's low and critical levels the lock screen says so; at this one it counts down a minute and hibernates, unless you plug in. Never leaves it to Plasma's own critical-battery action."

            Segmented {
                width: parent.width
                values: ["0", "2", "3", "5"]
                labels: ["Never", "At 2%", "At 3%", "At 5%"]
                current: String(root.lookValue("hibernateAt", "3"))
                onPicked: value => root.ctl.run(["set", "hibernateAt", value])
            }
        }

        ToggleRow {
            label: "What is playing"
            description: "The media card, from the same players Plasma's lock screen controls. This is Plasma's own setting."
            checked: root.lookBool("media")
            onToggled: value => root.ctl.run(["set", "media", value])
        }

        ToggleRow {
            label: "Sleep, hibernate and switch user"
            description: "The round buttons under the password."
            checked: root.lookBool("session")
            onToggled: value => root.ctl.run(["set", "session", value])
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Notifications are not shown on the lock screen. The greeter is a separate program with none of this shell's memory, and notification bodies are never written to disk for something else to read -- so there is nothing there to draw, and a switch that promised otherwise would be a lie."
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Locking" }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "When the screen locks -- after how long, on suspend, whether a password is needed straight away -- is Plasma's, and applies whichever lock screen is drawn."
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
        }

        Row {
            spacing: 8

            TextButton {
                glyph: "schedule"
                iconName: "preferences-desktop-screensaver"
                text: "Plasma's screen locking…"
                onActivated: PlasmaApplets.openSettings("kcm_screenlocker")
            }

            TextButton {
                glyph: "lock"
                iconName: "system-lock-screen"
                text: "Lock now"
                onActivated: Session.lock()
            }
        }
    }

    Card {
        width: root.width

        SectionLabel { text: "Ending the session" }

        ConfigSegmented {
            width: parent.width
            values: ["plasma", "shell"]
            labels: ["Plasma's prompt", "This shell's screen"]
            path: "session.prompt"
        }

        PanelText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Either way the session ends through Plasma's session manager, so applications are asked to save and one with unsaved work can still object. This only chooses which screen does the asking."
            font.pixelSize: 12
            lineHeight: 1.35
            color: Theme.mut
        }

        TextButton {
            glyph: "power_settings_new"
            iconName: "system-shutdown"
            text: "Show it"
            onActivated: Session.prompt("promptAll")
        }
    }
}
