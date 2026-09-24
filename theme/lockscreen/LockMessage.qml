/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What went wrong, and what else would unlock this.

    Three things share the space under the password because only one of them
    is ever interesting at a time: Caps Lock being on, whatever the
    authenticator said, and the readers the greeter says are actually there --
    a fingerprint sensor that exists, a smartcard that is in. `alternatives`
    is the greeter's own answer, so nothing is offered that cannot be used.

    Drawn by every style at its own width and colour.
*/
pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: message

    required property Unlock unlock

    property color ink: "#ffffff"
    property color warn: Qt.rgba(1, 0.86, 0.6, 1)
    property real unit: 1
    property int align: Text.AlignHCenter

    // The console style sets this to its own monospace; everything else
    // leaves it as the face the designs are drawn in.
    property string family: "Rubik"

    spacing: Math.round(10 * message.unit)

    Text {
        readonly property var parts: [
            LockKeys.caps ? "Caps Lock is on" : "",
            LockKeys.otherLayout && LockKeys.layoutName ? "Typing in " + LockKeys.layoutName : "",
            message.unlock.message,
        ].filter(p => p)

        width: message.width
        horizontalAlignment: message.align
        text: parts.join("\n")
        visible: parts.length > 0
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: message.unlock.message ? message.ink : message.warn
        font.family: message.family
        font.pixelSize: Math.round(13 * message.unit)
    }

    Row {
        readonly property var ways: [
            message.unlock.hasFingerprint ? "fingerprint" : "",
            message.unlock.hasSmartcard ? "badge" : "",
        ].filter(w => w)

        x: message.align === Text.AlignHCenter ? (message.width - width) / 2 : 0
        visible: ways.length > 0 && !message.unlock.unlockedWithoutPassword
        spacing: Math.round(10 * message.unit)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.ways[0] ?? ""
            font.family: "Material Symbols Rounded"
            font.pixelSize: Math.round(18 * message.unit)
            color: Qt.alpha(message.ink, 0.82)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (parent.ways[0] === "fingerprint" ? "Touch the sensor" : "Use your smartcard") + ", or type your password"
            textFormat: Text.PlainText
            font.family: message.family
            font.pixelSize: Math.round(13 * message.unit)
            color: Qt.alpha(message.ink, 0.82)
        }
    }
}
