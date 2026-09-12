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
