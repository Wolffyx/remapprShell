/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What the lock screen draws: the wallpaper and a big clock while nothing is
    happening; at a key, a touch or the pointer moving, the wallpaper blurs and
    the prompt comes up -- who is locked out, the password, what went wrong,
    what is playing, and sleep, hibernate and switch user.

    Whether to unlock is decided in Unlock.qml, never here. The controls that
    decide anything are Plasma's own -- its password field, its on-screen
    keyboard, its battery and layout indicators, its media players -- laid out
    and coloured by us.

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
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.workspace.components as PW
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
    readonly property bool clockLeft: Options.clockPosition !== "center"
    readonly property int blurAmount: Options.wallpaperBlur

    // The design's proportions are drawn at 1920x1080; a smaller screen gets
    // the same layout, scaled down, rather than a clock running off the edge.
    readonly property real unit: Math.max(0.62, Math.min(1, ui.height / 1080))
    readonly property int edge: Math.round(96 * ui.unit)

    readonly property color fg: "#ffffff"
    readonly property color fgDim: Qt.rgba(1, 1, 1, 0.82)

    function focusPassword() {
        passwordBox.forceActiveFocus();
    }

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    Component.onCompleted: ui.focusPassword()

    Connections {
        target: ui.unlock
        function onClearPassword() {
            passwordBox.text = "";
            passwordBox.text = Qt.binding(() => PasswordSync.password);
            passwordBox.showPassword = false;
            ui.focusPassword();
        }
        function onSecretRequested() {
            passwordBox.showPassword = false;
            ui.focusPassword();
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

    KeyboardIndicator.KeyState {
        id: capsLock
        key: Qt.Key_CapsLock
    }

    // A key reaching here missed the password field: focus was on a button.
    // Move it back, and keep the character.
    Keys.onPressed: event => {
        ui.unlock.poke();
        const special = [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Escape, Qt.Key_Tab, Qt.Key_Backtab];
        if (event.text.length > 0 && !special.includes(event.key) && !ui.unlock.resting) {
            passwordBox.insert(passwordBox.cursorPosition, event.text);
            event.accepted = true;
        }
        ui.focusPassword();
    }

    // --- the wallpaper ---------------------------------------------------

    MultiEffect {
        anchors.fill: parent
        source: ui.wallpaper
        visible: ui.wallpaper !== null && opacity > 0 && ui.blurAmount > 0
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
    // blurred one behind the prompt.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.04, 0.03, 0.03, ui.unlock.shown ? 0.34 : 0.26) }
            GradientStop { position: 0.5; color: Qt.rgba(0.04, 0.03, 0.03, ui.unlock.shown ? 0.42 : 0.24) }
            GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.03, 0.03, ui.unlock.shown ? 0.62 : 0.44) }
        }
    }

    // --- the clock -------------------------------------------------------

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }

    Column {
        id: clock

        property date now: new Date()

        x: ui.clockLeft ? ui.edge : (ui.width - width) / 2
        y: ui.unlock.shown ? Math.round(ui.height * 0.1) : Math.round(ui.height * 0.3)
        spacing: 0
        opacity: ui.showClock ? 1 : 0

        Behavior on y { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        // The shadow is the text's own. A layer effect on the clock drew
        // nothing at all in the greeter, offscreen -- and a lock screen is
        // no place to find out which GPUs share that.
        Text {
            anchors.horizontalCenter: ui.clockLeft ? undefined : parent.horizontalCenter
            text: clock.now.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
            textFormat: Text.PlainText
            color: ui.fg
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.4)
            font.family: "Rubik"
            font.pixelSize: Math.round(132 * ui.unit)
            font.weight: Font.ExtraLight
            font.letterSpacing: -Math.round(4 * ui.unit)
        }

        Text {
            anchors.horizontalCenter: ui.clockLeft ? undefined : parent.horizontalCenter
            topPadding: Math.round(14 * ui.unit)
            text: clock.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
            textFormat: Text.PlainText
            color: Qt.rgba(1, 1, 1, 0.86)
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.4)
            font.family: "Rubik"
            font.pixelSize: Math.round(22 * ui.unit)
        }

        Item {
            width: pill.width
            height: pill.height + Math.round(20 * ui.unit)
            anchors.horizontalCenter: ui.clockLeft ? undefined : parent.horizontalCenter

            Rectangle {
                id: pill

                y: Math.round(20 * ui.unit)
                width: pillRow.width + 26
                height: 34
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.16)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.22)

                Row {
                    id: pillRow

                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "lock"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 17
                        color: ui.fg
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ui.unlock.resting ? "Locked · wait a moment" : "Locked"
                        textFormat: Text.PlainText
                        font.family: "Rubik"
                        font.pixelSize: 13
                        color: ui.fg
                    }
                }
            }
        }
    }

    // --- the prompt ------------------------------------------------------

    // Plasma's on-screen keyboard moves this up out of its way, which is why
    // the prompt sits in a StackView of one page -- and why the StackView's id
    // must be `mainStack`: VirtualKeyboardLoader resolves that name as an id
    // through the creating context.
    QQC2.StackView {
        id: mainStack
        width: ui.width
        height: ui.height
        focus: true
        initialItem: promptPage
    }

    Item {
        id: promptPage

        // How far down the prompt must stay visible above the keyboard.
        readonly property int visibleBoundary: promptColumn.y + promptColumn.height + Kirigami.Units.largeSpacing

        opacity: ui.unlock.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }

        // What is playing, bottom left, from Plasma's own players.
        MediaCard {
            id: media

            x: ui.edge
            y: ui.height - height - Math.round(64 * ui.unit)
            width: Math.round(392 * ui.unit)
            visible: media.hasPlayer && ui.setting("showMediaControls", true) && ui.unlock.shown
            textColor: ui.fg
        }

        Column {
            id: promptColumn

            x: (ui.width - width) / 2
            y: ui.height - height - Math.round(110 * ui.unit)
            width: Math.round(392 * ui.unit)
            spacing: Math.round(18 * ui.unit)

            // The account's picture, or its initial. Kirigami's Avatar
            // is not in Kirigami since KF6, and the greeter draws Plasma's
            // built-in locker instead of a file that names it.
            Item {
                id: face

                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(96 * ui.unit)
                height: width

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 3
                    border.color: Qt.rgba(1, 1, 1, 0.5)
                    visible: picture.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text: ui.userName.length > 0 ? ui.userName[0].toUpperCase() : ""
                        textFormat: Text.PlainText
                        color: ui.fg
                        font.family: "Rubik"
                        font.pixelSize: Math.round(parent.height * 0.38)
                    }
                }

                Image {
                    id: picture
                    anchors.fill: parent
                    source: ui.userImage !== ""
                        ? "file://" + ui.userImage.split("/").map(encodeURIComponent).join("/")
                        : ""
                    sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: picture
                    visible: picture.status === Image.Ready
                    maskEnabled: true
                    maskSource: faceMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                Rectangle {
                    id: faceMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ui.userName
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: ui.fg
                font.family: "Rubik"
                font.pixelSize: Math.round(20 * ui.unit)
                font.weight: Font.Medium
            }

            // The password, in the design's pill. Everything inside it is
            // Plasma's field: what is typed, what is sent and when, and the
            // reveal button are all its own behaviour.
            Rectangle {
                id: passwordPill

                anchors.horizontalCenter: parent.horizontalCenter
                visible: !ui.unlock.unlockedWithoutPassword
                width: parent.width
                height: Math.round(58 * ui.unit)
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.16)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.28)
                opacity: ui.unlock.resting ? 0.6 : 1

                transform: Translate { id: shakeOffset }

                Text {
                    id: pwGlyph
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: "lock"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Qt.rgba(1, 1, 1, 0.8)
                }

                PlasmaExtras.PasswordField {
                    id: passwordBox

                    anchors.left: pwGlyph.right
                    anchors.leftMargin: 12
                    anchors.right: unlockButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    focus: true
                    text: PasswordSync.password
                    enabled: !ui.unlock.resting
                    placeholderText: "Password"
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.6)
                    color: ui.fg
                    font.family: "Rubik"
                    font.pixelSize: Math.round(17 * ui.unit)
                    background: null

                    // Only while the prompt shows: the cursor blinking is a
                    // redraw a second behind a hidden prompt.
                    cursorVisible: ui.unlock.shown

                    onTextChanged: {
                        if (text.length > 0)
                            ui.unlock.poke();
                    }

                    Keys.onPressed: event => {
                        const woke = !ui.unlock.shown;
                        ui.unlock.poke();
                        if (woke && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Escape].includes(event.key)) {
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Escape) {
                            ui.unlock.dismiss();
                            event.accepted = true;
                        }
                    }

                    onAccepted: unlockButton.clicked()
                }

                Binding {
                    target: PasswordSync
                    property: "password"
                    value: passwordBox.text
                }

                PlasmaComponents3.Button {
                    id: unlockButton

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(34 * ui.unit)
                    height: width
                    flat: false
                    icon.name: LayoutMirroring.enabled ? "go-previous" : "go-next"
                    enabled: !ui.unlock.resting
                    Accessible.name: "Unlock"

                    // Focus leaves the text field before the password is
                    // sent, as in Plasma's: a Qt bug once crashed an
                    // application quitting with a text field focused
                    // (QTBUG-55460), and here that application is the
                    // greeter, at the moment of unlocking.
                    onClicked: {
                        const password = passwordBox.text;
                        if (ui.unlock.submit(password))
                            unlockButton.forceActiveFocus();
                    }
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                }
            }

            PlasmaComponents3.Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: ui.unlock.unlockedWithoutPassword
                text: "Unlock"
                icon.name: "unlock"
                onClicked: ui.unlock.confirm()
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                onVisibleChanged: if (visible) forceActiveFocus()
            }

            Text {
                readonly property var parts: [
                    capsLock.locked ? "Caps Lock is on" : "",
                    ui.unlock.message,
                ].filter(p => p)

                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: parts.join("\n")
                visible: parts.length > 0
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: ui.unlock.message ? ui.fg : Qt.rgba(1, 0.86, 0.6, 1)
                font.family: "Rubik"
                font.pixelSize: Math.round(13 * ui.unit)
            }

            // What else would unlock this, when the greeter says so: a
            // fingerprint reader that is actually there, a smartcard that is
            // actually in.
            Row {
                readonly property var ways: [
                    (ui.unlock.alternatives & ui.unlock.fingerprint) ? "fingerprint" : "",
                    (ui.unlock.alternatives & ui.unlock.smartcard) ? "badge" : "",
                ].filter(w => w)

                anchors.horizontalCenter: parent.horizontalCenter
                visible: ways.length > 0 && !ui.unlock.unlockedWithoutPassword
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.ways[0] ?? ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: ui.fgDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (parent.ways[0] === "fingerprint" ? "Touch the sensor" : "Use your smartcard") + ", or type your password"
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(13 * ui.unit)
                    color: ui.fgDim
                }
            }

            // Sleep, hibernate, switch user -- the three the greeter can
            // actually do. Ending the session is not among them: the screen
            // is locked, and nobody has said who is asking.
            Row {
                id: sessionButtons

                anchors.horizontalCenter: parent.horizontalCenter
                visible: Options.showSessionButtons
                enabled: ui.unlock.shown
                spacing: 10

                component RoundAction: Item {
                    id: action

                    property string glyph: ""
                    property string label: ""
                    signal activated

                    width: Math.round(46 * ui.unit)
                    height: width

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: actionHover.hovered ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.22)

                        Text {
                            anchors.centerIn: parent
                            text: action.glyph
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Math.round(21 * ui.unit)
                            color: "#ffffff"
                        }
                    }

                    HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: action.activated() }
                    Accessible.name: action.label
                }

                RoundAction {
                    visible: ui.session.canSuspend
                    glyph: "bedtime"
                    label: "Sleep"
                    onActivated: ui.session.suspend()
                }

                RoundAction {
                    visible: ui.session.canHibernate
                    glyph: "downloading"
                    label: "Hibernate"
                    onActivated: ui.session.hibernate()
                }

                RoundAction {
                    visible: ui.session.canSwitchUser
                    glyph: "group"
                    label: "Switch user"
                    onActivated: ui.session.switchUser()
                }
            }
        }
    }

    SequentialAnimation {
        id: shake
        loops: 2
        NumberAnimation { target: shakeOffset; property: "x"; to: -Kirigami.Units.gridUnit / 2; duration: 40 }
        NumberAnimation { target: shakeOffset; property: "x"; to: Kirigami.Units.gridUnit / 2; duration: 80 }
        NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 40 }
    }

    Breeze.VirtualKeyboardLoader {
        id: inputPanel
        z: 1
        screenRoot: ui
        mainStack: mainStack
        mainBlock: promptPage
        passwordField: passwordBox
    }

    Binding {
        target: ui.unlock
        property: "keepShown"
        value: passwordBox.text.length > 0 || inputPanel.keyboardActive || ui.unlock.unlockedWithoutPassword
    }

    // --- the status pill -------------------------------------------------

    Rectangle {
        id: statusPill

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Math.round(44 * ui.unit)
        anchors.bottomMargin: Math.round(38 * ui.unit)
        width: statusRow.width + 32
        height: 44
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.2)
        opacity: ui.unlock.shown ? 1 : 0
        enabled: ui.unlock.shown
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        Row {
            id: statusRow

            anchors.centerIn: parent
            spacing: 14

            PlasmaComponents3.ToolButton {
                anchors.verticalCenter: parent.verticalCenter
                focusPolicy: Qt.TabFocus
                text: "On-screen keyboard"
                display: QQC2.AbstractButton.IconOnly
                icon.name: inputPanel.keyboardActive ? "input-keyboard-virtual-on" : "input-keyboard-virtual-off"
                visible: inputPanel.status === Loader.Ready
                onClicked: {
                    ui.focusPassword();
                    inputPanel.showHide();
                }
            }

            // The keyboard layout, named as the person set it up, and one
            // press away from the next one.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                visible: layouts.hasMultipleKeyboardLayouts
                width: layoutText.width
                height: layoutText.height

                Text {
                    id: layoutText
                    text: layouts.layoutNames.shortName
                    textFormat: Text.PlainText
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: ui.fg
                }

                PW.KeyboardLayoutSwitcher {
                    id: layouts
                    anchors.fill: parent
                }
            }

            Breeze.Battery {
                anchors.verticalCenter: parent.verticalCenter
            }
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
