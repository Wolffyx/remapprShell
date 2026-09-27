/*
    SPDX-License-Identifier: GPL-3.0-or-later

    A picture with its corners rounded, or cut to a circle: the account's
    face, a track's art.

    The picture is drawn through a MultiEffect masked by a rounded rectangle
    kept in a layer of its own, which is the way Qt Quick has of rounding an
    image. Nothing is drawn until the picture has loaded, so whatever stands
    in for it underneath shows until then; `status` says which it is.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

Item {
    id: pic

    property url source
    // Half the width is a circle.
    property real radius: 0
    property size sourceSize: Qt.size(pic.width * Screen.devicePixelRatio, pic.height * Screen.devicePixelRatio)
    property bool asynchronous: false

    readonly property int status: image.status

    Image {
        id: image

        anchors.fill: parent
        source: pic.source
        sourceSize: pic.sourceSize
        asynchronous: pic.asynchronous
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        visible: image.status === Image.Ready
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        radius: pic.radius
        visible: false
        layer.enabled: true
    }
}
