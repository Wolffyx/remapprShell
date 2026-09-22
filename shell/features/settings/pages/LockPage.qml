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
import Quickshell.Io
import qs.core
import qs.platform.kde
import qs.domain.config
import qs.domain.session
import qs.domain.surfaces
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    // `lockscreen status --json`, parsed.
    property var info: null
    property string status: ""
    property bool busy: false

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

    Component.onCompleted: root.refresh()

    function refresh() {
        readProc.running = false;
        readProc.running = true;
    }

    function run(args) {
        if (root.busy)
            return;
        root.status = "";
        runProc.command = [Branding.ctlBin, "lockscreen"].concat(args);
        runProc.running = true;
    }

    readonly property Process _read: Process {
        id: readProc
        command: [Branding.ctlBin, "lockscreen", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.info = JSON.parse(text);
                } catch (e) {
                    root.status = "Could not read the lock screen's state.";
                    Log.warn("settings", `lockscreen status: ${e}`);
                }
            }
        }
    }

    readonly property Process _run: Process {
        id: runProc
        onRunningChanged: {
            root.busy = running;
            if (!running)
                root.refresh();
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const errors = text.split("\n").filter(l => /error/i.test(l));
                if (errors.length > 0)
                    root.status = errors.pop().replace(/^.*error:?\s*/i, "");
            }
        }
    }

    PanelText {
        visible: root.status.length > 0
        width: root.width
        wrapMode: Text.WordWrap
        text: root.status
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
                enabled: !root.busy
                onActivated: root.run(["try"])
            }

            TextButton {
                visible: !root.installed
                primary: root.ready
                glyph: "lock"
                iconName: "lock"
                text: "Turn it on"
                enabled: !root.busy && root.ready
                onActivated: root.run(["enable"])
            }

            TextButton {
                visible: root.installed
                glyph: "lock_open"
                iconName: "unlock"
                text: "Turn it off"
                enabled: !root.busy
                onActivated: root.run(["disable"])
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

        // Seven lock screens, not seven colour schemes: they differ on where
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
                    TapHandler { onTapped: root.run(["set", "style", styleRow.modelData.id]) }
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
                onPicked: value => root.run(["set", "clock", value])
            }
        }

        SliderRow {
            // Four of the seven leave the wallpaper alone on purpose, and
            // two of them draw over it entirely.
            visible: ["glass", "board"].includes(root.lookValue("style", "glass"))
            label: "Wallpaper blur behind the prompt"
            from: 0
            to: 40
            stepSize: 2
            value: Number(root.lookValue("blur", 26))
            onMoved: value => root.run(["set", "blur", Math.round(value)])
        }

        ToggleRow {
            label: "Show the clock while nothing is happening"
            description: "Off, the screen is dark until a key or the pointer wakes the prompt."
            checked: root.lookBool("idleClock")
            onToggled: value => root.run(["set", "idleClock", value])
        }

        ToggleRow {
            label: "What is playing"
            description: "The media card, from the same players Plasma's lock screen controls. This is Plasma's own setting."
            checked: root.lookBool("media")
            onToggled: value => root.run(["set", "media", value])
        }

        ToggleRow {
            label: "Sleep, hibernate and switch user"
            description: "The round buttons under the password."
            checked: root.lookBool("session")
            onToggled: value => root.run(["set", "session", value])
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

        Segmented {
            width: parent.width
            values: ["plasma", "shell"]
            labels: ["Plasma's prompt", "This shell's screen"]
            current: ConfigStore.value("session.prompt", "plasma")
            onPicked: value => ConfigStore.set("session.prompt", value)
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
