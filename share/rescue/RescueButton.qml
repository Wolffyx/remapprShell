// A button for the rescue window: a rounded rectangle, a word, a press.
// Its own rather than QtQuick.Controls', whose style comes from the desktop
// and is one more thing that could be broken when this has to draw.

import QtQuick

Rectangle {
    id: root

    property alias text: label.text
    property color fg
    property color fill
    property color edge

    signal clicked()

    implicitWidth: label.implicitWidth + 32
    implicitHeight: 34
    radius: 17
    color: area.pressed ? Qt.darker(root.fill, 1.15) : area.containsMouse ? Qt.lighter(root.fill, 1.08) : root.fill
    border { width: 1; color: root.edge }

    Text {
        id: label
        anchors.centerIn: parent
        color: root.fg
        font { pixelSize: 13; weight: Font.Medium }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
