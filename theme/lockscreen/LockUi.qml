/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The frame every lock screen style is drawn in.

    This file owns what must exist exactly once and must not vary with the
    look: the wallpaper and its blur, waking on a key or the pointer, Plasma's
    on-screen keyboard and the StackView it moves, the shake when a password
    is refused, the OSD, and the binding that keeps the prompt up while
    something is half-typed. It draws no layout at all.

    The arrangement is a *style*: one file under `Options.style`, loaded here
    and handed this item to read. Seven of them, six from the design file's
    turns 1 and 2 and the seventh the glass one this project shipped first.
    A style that cannot be found falls back to glass rather than to an empty
    screen.

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
        function onRejected() { shake.start(); }
        function onMessageRepeated() { shake.start(); }
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
        opacity: ui.unlock.shown ? 1 : 0
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: ui.blurAmount / 40
        brightness: -0.12
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
