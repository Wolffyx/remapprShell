/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The frame every lock screen style is drawn in.

    This file owns what must exist exactly once and must not vary with the
    look: the wallpaper and its blur, waking on a key or the pointer, Plasma's
    on-screen keyboard and the StackView it moves, the shake when a password
    is refused, the OSD, and the binding that keeps the prompt up while
    something is half-typed. It draws no layout at all.

    The arrangement is a *style*: one file under `Options.style`, loaded here
    and handed this item to read. Twelve of them: eleven from the design
    file's four turns and the twelfth the glass one this project shipped
    first. A style that cannot be found falls back to glass rather than to an
    empty screen.

    Four things are drawn over whichever style it is, because the design's
    turn 4 draws them on every screen and none of them is a matter of look:
    the lockout countdown, the battery running out, the screen dimming to a
    clock when nobody is there, and the shutter lifting once the password is
    right.

    Whether to unlock is decided in Unlock.qml, never here and never in a
    style. The controls that decide anything are Plasma's own -- its password
    field, its on-screen keyboard, its battery and layout indicators, its
    media players -- laid out and coloured by us.

    Settings come from two places, because the greeter offers only one and it
    is not ours. Plasma's three (a clock at all, a clock while idle, media
    controls) arrive as `config`; this shell's own are read from a file by
    Options.qml, since the `config` object is built from the desktop package's
    config.xml rather than from the package being drawn -- measured, on 6.7.5.
    Nothing here can read the shell's configuration: none of the shell runs in
    the greeter.

    The password field keeps the keyboard even while the prompt is hidden,
    so the first key pressed is the first character of the password rather
    than a key spent waking the screen. Enter and Escape are the exceptions:
    pressed at a hidden prompt, they only wake it.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.breeze.components as Breeze

Item {
    id: ui

    required property Unlock unlock
    required property string userName
    // A path, or empty.
    required property string userImage
    // The greeter draws the wallpaper itself, behind everything; this is it,
    // to blur.
    required property Item wallpaper
    // Plasma's lock screen settings (System Settings -> Screen Locking ->
    // Appearance), kept rather than duplicated, plus this package's own.
    required property var config
    // SessionManagement: sleep, hibernate, switch user.
    required property var session

    function setting(name, fallback) {
        const v = ui.config ? ui.config[name] : undefined;
        return v === undefined || v === null ? fallback : v;
    }

    readonly property bool showClock: ui.setting("alwaysShowClock", true)
        && (ui.unlock.shown || !ui.setting("hideClockWhenIdle", false))
    readonly property int blurAmount: Options.wallpaperBlur

    // The design's proportions are drawn at 1920x1080; a smaller screen gets
    // the same layout, scaled down, rather than a clock running off the edge.
    readonly property real unit: Math.max(0.62, Math.min(1, ui.height / 1080))
    readonly property int edge: Math.round(96 * ui.unit)

    // The glass style's colours, which the others override for themselves.
    readonly property color fg: "#ffffff"
    readonly property color fgDim: Qt.rgba(1, 1, 1, 0.82)
    // Every style's focus ring, primary button and the border of a field
    // with the keyboard. Not the caret, which Plasma's field draws in the
    // text's own colour.
    readonly property color accent: Options.accent

    // When the lock screen started, which is as near as the greeter can know
    // to when the session was locked. "Locked 12 min ago" is read from this.
    readonly property date lockedAt: new Date()

    // No slides, no rolls, no shutter: a style asks for this (the accessible
    // one, when reduced motion is on) and the frame honours it too.
    readonly property bool reduceMotion: ui.style?.reduceMotion ?? false

    // --- leaving ----------------------------------------------------------

    // Set once the password was right. The greeter quits on `gone`, after the
    // shutter has lifted -- or at once, with the animation off. Either way a
    // timer makes sure it does: a lock screen that stayed up after saying yes
    // would be the one thing worse than one that said no.
    property bool leaving: false
    property real revealed: 0
    signal gone()

    function leave(): void {
        if (ui.leaving)
            return;
        ui.leaving = true;
        if (!Options.unlockAnimation || ui.reduceMotion)
            ui.gone();
        else
            shutter.start();
    }

    Timer {
        interval: 1500
        running: ui.leaving
        onTriggered: ui.gone()
    }

    ParallelAnimation {
        id: shutter

        NumberAnimation {
            target: lift
            property: "y"
            to: -ui.height
            duration: 750
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.6, 0, 0.2, 1, 1, 1]
        }
        NumberAnimation {
            target: ui
            property: "revealed"
            to: 1
            duration: 750
            easing.type: Easing.OutCubic
        }

        onFinished: ui.gone()
    }

    // --- dimming ----------------------------------------------------------

    property bool dimmed: false

    Timer {
        id: dimTimer
        interval: Math.max(1, Options.dimSeconds) * 1000
        running: Options.dimSeconds > 0 && !ui.dimmed && !ui.leaving && !power.dying
        onTriggered: ui.dimmed = true
    }

    // The styles, by the name `lockscreen set style` writes. Kept here rather
    // than built from the file name so that an unknown name is a fallback to
    // glass instead of a Loader with nothing in it -- the one failure a lock
    // screen must not have.
    readonly property var styles: ({
        "glass": "LockGlass.qml",
        "editorial": "LockEditorial.qml",
        "console": "LockConsole.qml",
        "ambient": "LockAmbient.qml",
        "board": "LockBoard.qml",
        "poster": "LockPoster.qml",
        "seats": "LockSeats.qml",
        "minimal": "LockMinimal.qml",
        "dayahead": "LockDayAhead.qml",
        "secure": "LockSecure.qml",
        "accessible": "LockAccessible.qml",
        "kiosk": "LockKiosk.qml",
    })

    readonly property string styleName: ui.styles[Options.style] !== undefined ? Options.style : "glass"

    // The style that is drawn, once the Loader has made it.
    readonly property LockStyle style: styleLoader.item as LockStyle

    // What the style built, or null before it has. Everything that reaches
    // into the style goes through these two.
    readonly property LockPrompt prompt: ui.style?.promptField ?? null
    readonly property Item promptBlock: ui.style?.promptBlock ?? null

    function focusPassword() {
        if (ui.prompt)
            ui.prompt.focusField();
    }

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    Component.onCompleted: {
        if (Options.style !== ui.styleName)
            console.warn("lock screen: no style called", Options.style, "-- drawing glass");
        ui.focusPassword();
    }

    Connections {
        target: ui.unlock
        function onActivity() {
            ui.dimmed = false;
            dimTimer.restart();
        }
        function onClearPassword() {
            if (ui.prompt)
                ui.prompt.clear();
        }
        function onSecretRequested() {
            if (ui.prompt) {
                ui.prompt.field.showPassword = false;
                ui.focusPassword();
            }
        }
        // The shake is motion, and reduced motion means none.
        function onRejected() { if (!ui.reduceMotion) shake.start(); }
        function onMessageRepeated() { if (!ui.reduceMotion) shake.start(); }
        function onShownChanged() {
            if (ui.unlock.shown)
                ui.focusPassword();
        }
    }

    Connections {
        target: ui.session
        function onAboutToSuspend() { ui.unlock.clearPassword(); }
    }

    // A key reaching here missed the password field: focus was on a button.
    // Move it back, and keep the character.
    Keys.onPressed: event => {
        ui.unlock.poke();
        const special = [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Escape, Qt.Key_Tab, Qt.Key_Backtab];
        if (event.text.length > 0 && !special.includes(event.key) && !ui.unlock.resting && ui.prompt) {
            ui.prompt.field.insert(ui.prompt.field.cursorPosition, event.text);
            event.accepted = true;
        }
        ui.focusPassword();
    }

    // --- the wallpaper ---------------------------------------------------

    MultiEffect {
        anchors.fill: parent
        source: ui.wallpaper
        visible: ui.wallpaper !== null && opacity > 0 && ui.blurAmount > 0
            && (ui.style?.blursWallpaper ?? true)
        opacity: ui.unlock.shown || ui.leaving ? 1 - ui.revealed : 0
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: ui.blurAmount / 40 * (1 - ui.revealed)
        brightness: -0.12 * (1 - ui.revealed)
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }
    }

    // Keeps the clock readable over a bright wallpaper, and settles the
    // blurred one behind the prompt. A style that draws its own background
    // turns it off rather than laying a second one over the first.
    Rectangle {
        anchors.fill: parent
        visible: ui.style?.scrimsWallpaper ?? true
        opacity: 1 - ui.revealed
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.04, 0.03, 0.03, ui.unlock.shown ? 0.34 : 0.26) }
            GradientStop { position: 0.5; color: Qt.rgba(0.04, 0.03, 0.03, ui.unlock.shown ? 0.42 : 0.24) }
            GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.03, 0.03, ui.unlock.shown ? 0.62 : 0.44) }
        }
    }

    // --- the style -------------------------------------------------------

    // Plasma's on-screen keyboard moves this up out of its way, which is why
    // the style sits in a StackView of one page -- and why the StackView's id
    // must be `mainStack`: VirtualKeyboardLoader resolves that name as an id
    // through the creating context.
    QQC2.StackView {
        id: mainStack
        width: ui.width
        height: ui.height
        focus: true
        initialItem: stylePage
        // The shutter. A transform rather than `y`, which the on-screen
        // keyboard moves for its own reasons.
        transform: Translate { id: lift }
    }

    Item {
        id: stylePage

        // How far down the style must stay visible above the keyboard.
        readonly property int visibleBoundary: ui.promptBlock
            ? ui.promptBlock.mapToItem(stylePage, 0, ui.promptBlock.height).y + Kirigami.Units.largeSpacing
            : stylePage.height

        // `setSource` rather than a `source` binding: a style's `ui` is a
        // required property, and a required property has to be there when the
        // item is made -- setting it in `onLoaded` is a frame too late, and
        // the greeter refuses the file for it.
        Loader {
            id: styleLoader

            anchors.fill: parent
            focus: true

            Component.onCompleted: styleLoader.setSource(ui.styles[ui.styleName], { "ui": ui })

            Connections {
                target: ui
                function onStyleNameChanged() {
                    styleLoader.setSource(ui.styles[ui.styleName], { "ui": ui });
                }
            }

            onLoaded: ui.focusPassword()

            // A style whose file will not load -- a mistake in it, a file
            // half-written -- is glass instead. The name alone falling back
            // is not enough: a known name with a broken file would otherwise
            // be a lock screen with nothing on it but the wallpaper.
            onStatusChanged: {
                if (styleLoader.status !== Loader.Error)
                    return;
                if (styleLoader.source.toString().endsWith(ui.styles.glass))
                    return;
                console.warn("lock screen: the", ui.styleName, "style did not load -- drawing glass");
                styleLoader.setSource(ui.styles.glass, { "ui": ui });
            }
        }
    }

    SequentialAnimation {
        id: shake
        loops: 2
        NumberAnimation { target: ui.prompt?.shakeTarget ?? null; property: "x"; to: -Kirigami.Units.gridUnit / 2; duration: 40 }
        NumberAnimation { target: ui.prompt?.shakeTarget ?? null; property: "x"; to: Kirigami.Units.gridUnit / 2; duration: 80 }
        NumberAnimation { target: ui.prompt?.shakeTarget ?? null; property: "x"; to: 0; duration: 40 }
    }

    Breeze.VirtualKeyboardLoader {
        id: inputPanel
        z: 1
        screenRoot: ui
        mainStack: mainStack
        mainBlock: stylePage
        passwordField: ui.prompt?.field ?? null
    }

    // Read by the styles, which draw the button that shows and hides it.
    readonly property Item keyboard: inputPanel

    Binding {
        target: ui.unlock
        property: "keepShown"
        value: (ui.prompt?.text.length ?? 0) > 0 || inputPanel.keyboardActive || ui.unlock.unlockedWithoutPassword
    }

    // --- over every style -------------------------------------------------

    LockPower {
        id: power
        z: 3
        anchors.fill: parent
        ui: ui
        visible: !ui.leaving
    }

    // The battery, for a style that draws one: this frame's, so that every
    // style reads the same one -- and a preview's stand-in reaches them all.
    readonly property LockPower battery: power

    LockLockout {
        z: 4
        anchors.horizontalCenter: parent.horizontalCenter
        y: (ui.style?.toastY ?? -1) >= 0 ? ui.style.toastY
                                          : Math.round((power.critical ? 96 : 66) * ui.unit)
        unlock: ui.unlock
        unit: ui.unit
        visible: counting && !ui.leaving
    }

    LockDim {
        z: 5
        anchors.fill: parent
        ui: ui
        dimmed: ui.dimmed && !ui.leaving
    }

    // For dev/preview/lock.sh: the states a picture cannot wait for.
    function simulate(what: var): void {
        if (what.battery)
            power.override = what.battery;
        if (what.lockout) {
            ui.unlock.lockedSpan = what.lockout * 1000;
            ui.unlock.lockedUntil = Date.now() + what.lockout * 1000;
        }
        if (what.dim)
            ui.dimmed = true;
        // Part of the way up, held there -- without `leaving`, whose timer
        // would quit the greeter before the picture was taken.
        if (what.leave) {
            lift.y = -ui.height * what.leave;
            ui.revealed = what.leave;
        }
    }

    LockOsd {
        z: 2
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Kirigami.Units.gridUnit * 3
        }
    }

    // --- waking ----------------------------------------------------------

    // Only the pointer actually moving wakes it. `point` changes far more
    // often than that -- continuously, with nothing moving, in the greeter
    // offscreen -- and waking on each change kept the prompt up for good.
    // The first position is where the pointer already was, not a person.
    HoverHandler {
        id: hover
        property point last: Qt.point(NaN, NaN)
        cursorShape: ui.unlock.shown ? Qt.ArrowCursor : Qt.BlankCursor
        onPointChanged: {
            const p = hover.point.position;
            const moved = Math.abs(p.x - hover.last.x) > 2 || Math.abs(p.y - hover.last.y) > 2;
            if (moved && !isNaN(hover.last.x))
                ui.unlock.poke();
            if (moved || isNaN(hover.last.x))
                hover.last = p;
        }
    }

    // While the prompt is hidden, a press only wakes it, and does not reach
    // whatever is invisibly underneath.
    MouseArea {
        anchors.fill: parent
        z: 10
        enabled: !ui.unlock.shown
        onPressed: ui.unlock.poke()
    }
}
