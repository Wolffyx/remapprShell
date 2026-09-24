/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Console (1b) -- no wallpaper, no glass. A tty-style prompt where
    everything is text and the keys are the whole interface.

    There is no picture to blur and nothing to darken, so both are off and
    the background is the style's own.

    The design's login banner names a kernel and a hostname. The greeter can
    read neither -- it has no session and this file has no way to open /proc --
    so the banner says what is actually known: the account, the screen, and
    what the authenticator has said so far. The F-keys are labelled with the
    things the greeter can really do on this machine, and they are bound: a
    style that printed "F12 poweroff" without binding it would be a picture of
    a console rather than one. So the design's F2 reboot and F12 poweroff are
    not here -- the greeter cannot do either -- and neither is F3, which
    showed notifications the greeter never receives. What is: F1 sleep, F2
    hibernate, F3 switch user, F4 play or pause, Ctrl+U to clear the line.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

LockStyle {
    id: console_

    readonly property color ink: "#cdc6be"
    readonly property color mut: "#8a8378"
    readonly property color accent: console_.ui.accent
    readonly property color warn: "#e0c98a"

    blursWallpaper: false
    scrimsWallpaper: false

    promptField: password
    promptBlock: block

    // "12 min ago", from when the greeter started, redrawn each minute.
    property date now: new Date()
    readonly property string lockedFor: LockText.ago(console_.ui.lockedAt, console_.now, false)

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: console_.now = new Date()
    }

    // The one player Plasma's lock screen would control, or null.
    readonly property var player: console_.ui.setting("showMediaControls", true) ? LockKeys.player : null

    readonly property var keys: [
        { key: "F1", label: "sleep", can: console_.ui.session.canSuspend && Options.showSessionButtons,
          run: () => console_.ui.session.suspend() },
        { key: "F2", label: "hibernate", can: console_.ui.session.canHibernate && Options.showSessionButtons,
          run: () => console_.ui.session.hibernate() },
        { key: "F3", label: "switch user", can: console_.ui.session.canSwitchUser && Options.showSessionButtons,
          run: () => console_.ui.session.switchUser() },
        { key: "F4", label: console_.player?.playbackStatus === Mpris.PlaybackStatus.Playing ? "pause" : "play",
          can: console_.player !== null && console_.player.canControl,
          run: () => console_.player.container.PlayPause() },
        { key: "ctrl+u", label: "clear", can: true,
          run: () => password.clear() },
    ]

    // Bound whether or not the prompt is showing: a key that only worked
    // after a first key had woken the screen would be two keys.
    Shortcut { sequence: "F1"; enabled: console_.keys[0].can; onActivated: console_.keys[0].run() }
    Shortcut { sequence: "F2"; enabled: console_.keys[1].can; onActivated: console_.keys[1].run() }
    Shortcut { sequence: "F3"; enabled: console_.keys[2].can; onActivated: console_.keys[2].run() }
    Shortcut { sequence: "F4"; enabled: console_.keys[3].can; onActivated: console_.keys[3].run() }
    Shortcut { sequence: "Ctrl+U"; onActivated: console_.keys[4].run() }

    Rectangle {
        anchors.fill: parent
        color: "#0d0c0b"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(console_.accent, 0.16) }
            GradientStop { position: 0.6; color: "transparent" }
        }
    }

    Text {
        x: Math.round(120 * console_.unit)
        y: Math.round(96 * console_.unit)
        text: `${Screen.name} · ${Screen.width}×${Screen.height} · ${clockLine.now.toLocaleString(Qt.locale(), "ddd d MMM HH:mm:ss")}`
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"
        font.pixelSize: Math.round(15 * console_.unit)
        color: console_.mut
    }

    LockClock {
        id: clockLine

        x: console_.width - width - Math.round(120 * console_.unit)
        y: Math.round(88 * console_.unit)
        opacity: console_.ui.showClock ? 1 : 0
        showDate: false
        raised: false
        family: "JetBrains Mono"
        ink: console_.ink
        timeSize: Math.round(76 * console_.unit)
        timeWeight: Font.Medium

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
    }

    // --- the session ------------------------------------------------------

    Item {
        id: block

        x: Math.round(120 * console_.unit)
        y: Math.round(248 * console_.unit)
        width: Math.min(Math.round(1140 * console_.unit), console_.width - 2 * x)
        height: body.height

        Rectangle {
            width: 2
            height: parent.height
            color: console_.accent
        }

        Column {
            id: body

            x: Math.round(34 * console_.unit)
            width: parent.width - x
            spacing: 0

            // The mark, drawn as four cells of a terminal rather than as a
            // logo: the one piece of this style that is not type.
            Row {
                spacing: Math.round(14 * console_.unit)

                Grid {
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 2
                    spacing: Math.round(4 * console_.unit)

                    Repeater {
                        model: [console_.accent, console_.mut, console_.mut, console_.warn]

                        Rectangle {
                            required property color modelData
                            width: Math.round(13 * console_.unit)
                            height: width
                            color: modelData
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "locked session"
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.round(21 * console_.unit)
                    font.weight: Font.Medium
                    color: console_.ink
                }
            }

            Item {
                width: parent.width
                height: Math.round(54 * console_.unit) + login.height

                Text {
                    id: login

                    anchors.bottom: parent.bottom
                    text: "login: "
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.round(24 * console_.unit)
                    color: console_.mut

                    Text {
                        anchors.left: parent.right
                        anchors.baseline: parent.baseline
                        text: console_.ui.userName
                        textFormat: Text.PlainText
                        font: parent.font
                        color: console_.ink
                    }
                }
            }

            Item {
                width: parent.width
                height: password.height + Math.round(22 * console_.unit)

                Text {
                    id: pwLabel

                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(6 * console_.unit)
                    text: "Password: "
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.round(24 * console_.unit)
                    color: console_.mut
                }

                LockPrompt {
                    id: password

                    anchors.left: pwLabel.right
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    unlock: console_.ui.unlock
                    unit: console_.unit
                    chrome: "bare"
                    glyph: ""
                    placeholder: ""
                    showButton: false
                    ink: console_.ink
                    dim: console_.mut
                }
            }

            LockMessage {
                topPadding: Math.round(34 * console_.unit)
                width: parent.width
                unlock: console_.ui.unlock
                unit: console_.unit
                align: Text.AlignLeft
                family: "JetBrains Mono"
                ink: console_.ink
                warn: console_.warn
            }

            Text {
                topPadding: Math.round(14 * console_.unit)
                text: console_.ui.unlock.resting
                    ? "too many attempts · the authenticator is resting"
                    : "type your password, then Enter"
                textFormat: Text.PlainText
                font.family: "JetBrains Mono"
                font.pixelSize: Math.round(17 * console_.unit)
                color: console_.mut
            }

            // What the greeter knows about itself, as a tty's login banner
            // says it: how long ago it locked, and what is playing.
            Column {
                topPadding: Math.round(48 * console_.unit)
                spacing: Math.round(12 * console_.unit)

                Text {
                    text: "Screen locked " + console_.lockedFor
                    textFormat: Text.PlainText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.round(17 * console_.unit)
                    color: console_.mut
                }

                Repeater {
                    model: console_.player ? [console_.player] : []

                    Text {
                        required property var modelData
                        text: "♪ " + [modelData.track, modelData.artist].filter(t => t).join(" — ")
                            + " · F4 to " + (modelData.playbackStatus === Mpris.PlaybackStatus.Playing ? "pause" : "play")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        width: body.width
                        font.family: "JetBrains Mono"
                        font.pixelSize: Math.round(17 * console_.unit)
                        color: console_.mut
                    }
                }
            }

            // The keys, as a tty would print them, and each one bound.
            Flow {
                topPadding: Math.round(48 * console_.unit)
                width: parent.width
                spacing: Math.round(10 * console_.unit)
                enabled: console_.ui.unlock.shown

                Repeater {
                    model: console_.keys.filter(k => k.can)

                    Rectangle {
                        id: chip

                        required property var modelData

                        width: chipText.implicitWidth + Math.round(30 * console_.unit)
                        height: chipText.implicitHeight + Math.round(18 * console_.unit)
                        color: "transparent"
                        border.width: 1
                        border.color: chipHover.hovered ? "#5a534b" : "#2f2b27"

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: `<span style="color:${console_.ink}">${chip.modelData.key}</span>&nbsp; ${chip.modelData.label}`
                            textFormat: Text.StyledText
                            font.family: "JetBrains Mono"
                            font.pixelSize: Math.round(15 * console_.unit)
                            color: console_.mut
                        }

                        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                chip.modelData.run();
                                console_.ui.focusPassword();
                            }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: chip.modelData.label
                    }
                }
            }
        }
    }

    // --- the foot ---------------------------------------------------------

    Item {
        x: Math.round(120 * console_.unit)
        width: console_.width - 2 * x
        height: Math.round(44 * console_.unit)
        y: console_.height - height - Math.round(120 * console_.unit)
        enabled: console_.ui.unlock.shown

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#1e1c1a"
        }

        LockStatus {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            keyboard: console_.ui.keyboard
            ink: console_.ink
            textSize: Math.round(15 * console_.unit)
            onFocusRequested: console_.ui.focusPassword()
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: "pam_unix · the account's own attempt limit applies"
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(15 * console_.unit)
            color: console_.mut
        }
    }
}
