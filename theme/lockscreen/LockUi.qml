/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What the lock screen draws. Idle, the wallpaper and a clock; at a key,
    a touch or the pointer moving, the wallpaper blurs and the prompt comes
    up: who is locked out, the password field, what went wrong, and sleep,
    hibernate and switch user.

    Whether to unlock is decided in Unlock.qml, never here. The controls are
    Plasma's own -- its password field, its on-screen keyboard, its battery
    and layout indicators -- rethemed by the colour scheme and laid out by us.

    The password field keeps the keyboard even while the prompt is hidden,
    so the first key pressed is the first character of the password rather
    than a key spent waking the screen. Enter and Escape are the exceptions:
    pressed at a hidden prompt, they only wake it.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
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
    // Appearance), kept rather than duplicated.
    required property var config
    // SessionManagement: sleep, hibernate, switch user.
    required property var session

    function setting(name, fallback) {
        const v = ui.config ? ui.config[name] : undefined;
        return v === undefined || v === null ? fallback : v;
    }

    readonly property bool showClock: ui.setting("alwaysShowClock", true)
        && (ui.unlock.shown || !ui.setting("hideClockWhenIdle", false))

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
        visible: ui.wallpaper !== null && opacity > 0
        opacity: ui.unlock.shown ? 1 : 0
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: 1
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
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, ui.unlock.shown ? 0.35 : 0.25) }
            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, ui.unlock.shown ? 0.35 : 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, ui.unlock.shown ? 0.45 : 0.3) }
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

    ColumnLayout {
        id: clock
        property date now: new Date()

        anchors.horizontalCenter: parent.horizontalCenter
        y: ui.unlock.shown ? ui.height * 0.08 : ui.height * 0.3 - height / 2
        spacing: 0
        scale: ui.unlock.shown ? 0.55 : 1
        transformOrigin: Item.Top
        opacity: ui.showClock ? 1 : 0

        Behavior on y { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        // The shadow is the text's own. A layer effect on the clock drew
        // nothing at all in the greeter, offscreen -- and a lock screen is
        // no place to find out which GPUs share that.
        PlasmaComponents3.Label {
            text: clock.now.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
            color: Kirigami.Theme.textColor
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.45)
            font.pixelSize: Kirigami.Units.gridUnit * 6
            font.weight: Font.Light
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignHCenter
        }

        PlasmaComponents3.Label {
            text: clock.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
            color: Kirigami.Theme.textColor
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.45)
            font.pixelSize: Kirigami.Units.gridUnit * 1.4
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // --- the prompt ------------------------------------------------------

    // Plasma's on-screen keyboard moves this up out of its way, which is why
    // the prompt sits in a StackView of one page.
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
        readonly property int visibleBoundary: card.y + card.height + Kirigami.Units.largeSpacing

        opacity: ui.unlock.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }

        Rectangle {
            id: card

            width: Math.min(ui.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 22)
            height: column.implicitHeight + Kirigami.Units.gridUnit * 2.5
            x: (ui.width - width) / 2
            y: ui.height * 0.56 - height / 2
            radius: Kirigami.Units.gridUnit
            color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g,
                           Kirigami.Theme.backgroundColor.b, 0.55)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                  Kirigami.Theme.textColor.b, 0.08)

            ColumnLayout {
                id: column
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: Kirigami.Units.gridUnit * 1.25
                }
                spacing: Kirigami.Units.largeSpacing

                // The account's picture, or its initial. Kirigami's Avatar
                // is not in Kirigami since KF6, and the greeter draws Plasma's
                // built-in locker instead of a file that names it.
                Item {
                    id: face
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 4.5
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 4.5
                    Layout.alignment: Qt.AlignHCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Kirigami.Theme.highlightColor
                        visible: picture.status !== Image.Ready

                        PlasmaComponents3.Label {
                            anchors.centerIn: parent
                            text: ui.userName.length > 0 ? ui.userName[0].toUpperCase() : ""
                            color: Kirigami.Theme.highlightedTextColor
                            font.pixelSize: parent.height * 0.45
                            textFormat: Text.PlainText
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

                Kirigami.Heading {
                    level: 2
                    text: ui.userName
                    color: Kirigami.Theme.textColor
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                RowLayout {
                    id: passwordRow
                    visible: !ui.unlock.unlockedWithoutPassword
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing

                    transform: Translate { id: shakeOffset }

                    PlasmaExtras.PasswordField {
                        id: passwordBox

                        focus: true
                        text: PasswordSync.password
                        enabled: !ui.unlock.resting
                        placeholderText: "Password"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                        Layout.fillWidth: true

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

                        icon.name: LayoutMirroring.enabled ? "go-previous" : "go-next"
                        enabled: !ui.unlock.resting
                        Accessible.name: "Unlock"
                        Layout.preferredHeight: passwordBox.implicitHeight
                        Layout.preferredWidth: passwordBox.implicitHeight

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
                    visible: ui.unlock.unlockedWithoutPassword
                    text: "Unlock"
                    icon.name: "unlock"
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: ui.unlock.confirm()
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                    onVisibleChanged: if (visible) forceActiveFocus()
                }

                PlasmaComponents3.Label {
                    readonly property var parts: [
                        capsLock.locked ? "Caps Lock is on" : "",
                        ui.unlock.message,
                    ].filter(p => p)

                    text: parts.join("\n")
                    visible: parts.length > 0
                    color: ui.unlock.message ? Kirigami.Theme.textColor : Kirigami.Theme.neutralTextColor
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    readonly property var ways: [
                        (ui.unlock.alternatives & ui.unlock.fingerprint) ? "scan your fingerprint" : "",
                        (ui.unlock.alternatives & ui.unlock.smartcard) ? "use your smartcard" : "",
                    ].filter(w => w)

                    visible: ways.length > 0 && !ui.unlock.unlockedWithoutPassword
                    text: "Or " + ways.join(", or ")
                    opacity: 0.7
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }

        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            y: card.y + card.height + Kirigami.Units.gridUnit
            spacing: Kirigami.Units.gridUnit
            enabled: ui.unlock.shown

            Breeze.ActionButton {
                text: "Sleep"
                icon.name: "system-suspend"
                visible: ui.session.canSuspend
                onClicked: ui.session.suspend()
            }
            Breeze.ActionButton {
                text: "Hibernate"
                icon.name: "system-suspend-hibernate"
                visible: ui.session.canHibernate
                onClicked: ui.session.hibernate()
            }
            Breeze.ActionButton {
                text: "Switch User"
                icon.name: "system-switch-user"
                visible: ui.session.canSwitchUser
                onClicked: ui.session.switchUser()
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

    // --- the footer ------------------------------------------------------

    RowLayout {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: Kirigami.Units.smallSpacing
        }
        spacing: Kirigami.Units.smallSpacing
        opacity: ui.unlock.shown ? 1 : 0
        enabled: ui.unlock.shown
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        PlasmaComponents3.ToolButton {
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

        PlasmaComponents3.ToolButton {
            focusPolicy: Qt.TabFocus
            icon.name: "input-keyboard"
            text: layouts.layoutNames.longName
            visible: layouts.hasMultipleKeyboardLayouts
            onClicked: layouts.keyboardLayout.switchToNextLayout()

            PW.KeyboardLayoutSwitcher {
                id: layouts
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
            }
        }

        Item { Layout.fillWidth: true }

        Breeze.Battery {}
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
