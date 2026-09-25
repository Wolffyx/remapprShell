/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The account's picture, or its initial.

    Kirigami's Avatar is not in Kirigami since KF6, and the greeter draws
    Plasma's built-in locker instead of a file that names it -- so this is
    drawn here: the picture masked to a circle when there is one, the first
    letter of the name when there is not.

    Every style shows a face somewhere, at a different size and over a
    different background, so the ring and the letter take their colours from
    the style rather than assuming white on a photograph.
*/
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: face

    // A path, or empty.
    required property string image
    required property string userName

    property color ink: "#ffffff"
    property color fill: Qt.rgba(1, 1, 1, 0.2)
    property color ring: Qt.rgba(1, 1, 1, 0.5)
    property int ringWidth: 3

    // A gradient stands in for a picture in the designs; a real account
    // usually has neither, so the letter sits on the style's own fill.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: face.fill
        border.width: face.ringWidth
        border.color: face.ring
        visible: picture.status !== Image.Ready

        Text {
            anchors.centerIn: parent
            text: face.userName.length > 0 ? face.userName[0].toUpperCase() : ""
            textFormat: Text.PlainText
            color: face.ink
            font.family: "Rubik"
            font.pixelSize: Math.round(parent.height * 0.38)
        }
    }

    LockPicture {
        id: picture

        anchors.fill: parent
        radius: width / 2
        source: face.image !== ""
            ? "file://" + face.image.split("/").map(encodeURIComponent).join("/")
            : ""
    }
}
