/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The password, in whatever shape a style asks for.

    Everything inside is Plasma's own field: what is typed, what is sent and
    when, and the reveal button are all its behaviour, and none of it is
    reimplemented here. What this adds is the chrome the designs differ on --
    a pill, an underline, a bare tty line -- and the one place the frame
    reaches for when it needs to focus, shake, or keep the field above the
    on-screen keyboard.

    Drawn by every style, so a change to how a password is taken is a change
    in one file. A style that wanted its own would be a second implementation
    of the only part of this project that can lock somebody out.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras

Item {
    id: prompt

    required property Unlock unlock

    // The colours, which every style sets. The defaults are the glass ones.
    // The caret is drawn in `ink`: it is Plasma's field's own.
    property color ink: "#ffffff"
    property color dim: Qt.rgba(1, 1, 1, 0.6)
    property color accent: Options.accent
    property color errorColor: "#e0786a"

    // The chrome. `pill` is the rounded field of the glass and poster styles;
    // `underline` is a hairline under the text, as the ambient and editorial
    // ones draw it; `bare` is the console's, which is just monospace text;
    // `none` draws nothing at all, for a style whose own card is the field.
    property string chrome: "pill"

    property color fieldColor: Qt.rgba(1, 1, 1, 0.16)
    property color fieldBorder: Qt.rgba(1, 1, 1, 0.28)
    property int radius: height / 2

    // The border that says what the field is doing, for the styles that
    // draw a box round it: the error colour while `alarm` holds, the accent
    // while the field has the keyboard, and `restBorder` otherwise. `alarm`
    // is a refused password resting; the day-ahead style makes it anything
    // said at all, and keeps its box red for as long as the message stays.
    property bool alarm: prompt.unlock.resting
    property color restBorder: Qt.rgba(0.5, 0.5, 0.5, 0.32)
    readonly property color stateBorder: prompt.alarm ? prompt.errorColor
        : passwordBox.activeFocus ? prompt.accent
        : prompt.restBorder

    // The glyph at the head of the field. Empty draws none.
    property string glyph: "lock"
    property string placeholder: "Password"

    // The round arrow at the end. The console style sends with Enter alone.
    property bool showButton: true

    property real unit: 1
    property alias field: passwordBox
    property alias text: passwordBox.text

    // The frame shakes this when a password is refused.
    readonly property alias shakeTarget: shakeOffset

    implicitHeight: chrome === "pill" ? Math.round(58 * prompt.unit)
                                      : Math.round(44 * prompt.unit)

    function focusField(): void {
        passwordBox.forceActiveFocus();
    }

    // Called by the frame when the authenticator asks for the secret again,
    // or when a password was refused: the field is cleared without losing the
    // binding that keeps it in step with the other screens.
    function clear(): void {
        passwordBox.text = "";
        passwordBox.text = Qt.binding(() => PasswordSync.password);
        passwordBox.showPassword = false;
        prompt.focusField();
    }

    // The reveal button inside Plasma's field is Kirigami's to colour; see
    // LockStatus for why this is set rather than overridden.
    Kirigami.Theme.inherit: false
    Kirigami.Theme.textColor: prompt.ink

    transform: Translate { id: shakeOffset }

    opacity: prompt.unlock.resting ? 0.6 : 1

    // The greeter can decide the session is already unlocked -- another seat
    // took the lock, or an alternative reader answered -- and then there is
    // nothing to type. Everything that takes a password hides, and one button
    // is left that confirms it.
    readonly property bool takesPassword: !prompt.unlock.unlockedWithoutPassword

    PlasmaComponents3.Button {
        anchors.centerIn: parent
        visible: !prompt.takesPassword
        text: "Unlock"
        icon.name: "unlock"
        onClicked: prompt.unlock.confirm()
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
        onVisibleChanged: if (visible) forceActiveFocus()
    }

    // --- the chrome ------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        visible: prompt.takesPassword && prompt.chrome === "pill"
        radius: prompt.radius
        color: prompt.fieldColor
        border.width: 1
        border.color: prompt.fieldBorder
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: prompt.takesPassword && prompt.chrome === "underline"
        height: Math.max(1, Math.round(1.5 * prompt.unit))
        color: prompt.fieldBorder
    }

    // --- the field -------------------------------------------------------

    Text {
        id: pwGlyph

        x: prompt.chrome === "pill" ? Math.round(20 * prompt.unit) : 0
        anchors.verticalCenter: parent.verticalCenter
        visible: prompt.takesPassword && prompt.glyph !== ""
        text: prompt.glyph
        font.family: "Material Symbols Rounded"
        font.pixelSize: Math.round(20 * prompt.unit)
        color: prompt.dim
    }

    PlasmaExtras.PasswordField {
        id: passwordBox

        anchors.left: pwGlyph.visible ? pwGlyph.right : parent.left
        anchors.leftMargin: pwGlyph.visible ? Math.round(12 * prompt.unit) : 0
        anchors.right: unlockButton.visible ? unlockButton.left : parent.right
        anchors.rightMargin: unlockButton.visible ? Math.round(8 * prompt.unit) : 0
        anchors.verticalCenter: parent.verticalCenter

        focus: true
        visible: prompt.takesPassword
        text: PasswordSync.password
        enabled: !prompt.unlock.resting
        placeholderText: prompt.placeholder
        placeholderTextColor: prompt.dim
        color: prompt.ink
        font.family: prompt.chrome === "bare" ? "JetBrains Mono" : "Rubik"
        font.pixelSize: Math.round((prompt.chrome === "bare" ? 24 : 17) * prompt.unit)
        background: null

        // Only while the prompt shows: the cursor blinking is a redraw a
        // second behind a hidden prompt.
        cursorVisible: prompt.unlock.shown

        onTextChanged: {
            if (text.length > 0)
                prompt.unlock.poke();
        }

        Keys.onPressed: event => {
            const woke = !prompt.unlock.shown;
            prompt.unlock.poke();
            if (woke && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Escape].includes(event.key)) {
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                prompt.unlock.dismiss();
                event.accepted = true;
            }
        }

        onAccepted: prompt.submit()
    }

    Binding {
        target: PasswordSync
        property: "password"
        value: passwordBox.text
    }

    // Focus leaves the text field before the password is sent, as in
    // Plasma's: a Qt bug once crashed an application quitting with a text
    // field focused (QTBUG-55460), and here that application is the greeter,
    // at the moment of unlocking.
    function submit(): void {
        const password = passwordBox.text;
        if (!prompt.unlock.submit(password))
            return;
        // Somewhere other than the field, and somewhere that exists: a style
        // with no button still has the prompt itself.
        if (unlockButton.visible)
            unlockButton.forceActiveFocus();
        else
            prompt.forceActiveFocus();
    }

    PlasmaComponents3.Button {
        id: unlockButton

        anchors.right: parent.right
        anchors.rightMargin: prompt.chrome === "pill" ? Math.round(12 * prompt.unit) : 0
        anchors.verticalCenter: parent.verticalCenter
        visible: prompt.takesPassword && prompt.showButton
        width: Math.round(34 * prompt.unit)
        height: width
        flat: false
        icon.name: LayoutMirroring.enabled ? "go-previous" : "go-next"
        enabled: !prompt.unlock.resting
        Accessible.name: "Unlock"

        onClicked: prompt.submit()
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
    }
}
