pragma ComponentBehavior: Bound

// What a notification is about, when that is a picture: a screenshot is
// unrecognisable as a file name and obvious as a thumbnail. It takes no room
// when there is none, or when it will not load.

import QtQuick
import qs.domain.theme

Item {
    id: pic

    required property string source
    property int pictureHeight: 120
    property size sourceSize: Qt.size(760, 360)

    width: parent ? parent.width : 0
    height: visible ? pic.pictureHeight + 8 : 0
    visible: pic.source.length > 0 && shot.status !== Image.Error

    Rectangle {
        y: 8
        width: parent.width
        height: pic.pictureHeight
        radius: Theme.radiusOf(12)
        color: Theme.s2
        clip: true

        Image {
            id: shot
            anchors.fill: parent
            source: pic.source
            sourceSize: pic.sourceSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }
}
