/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The time, and the date under it.

    One timer, ticking once a second, shared by whichever style is drawn --
    the designs differ on size, weight and where the line breaks, not on what
    a clock is. Both lines are the locale's own: `ShortFormat` for the time
    so a machine set to twelve hours shows twelve, `LongFormat` for the date.

    The shadow is the text's own. A layer effect on the clock drew nothing at
    all in the greeter, offscreen -- and a lock screen is no place to find out
    which GPUs share that.
*/
pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: clock

    property date now: new Date()

    property color ink: "#ffffff"
    property color dateInk: Qt.rgba(1, 1, 1, 0.86)
    property int timeSize: 132
    property int dateSize: 22
    property int timeWeight: Font.ExtraLight
    property string family: "Rubik"
    property bool raised: true
    property bool centred: false
    property bool showDate: true

    // A second line beside the date, where a style has something true to put
    // there. Empty draws nothing rather than a separator with nothing after it.
    property string aside: ""

    spacing: 0

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }

    Text {
        anchors.horizontalCenter: clock.centred ? parent.horizontalCenter : undefined
        text: clock.now.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
        textFormat: Text.PlainText
        color: clock.ink
        style: clock.raised ? Text.Raised : Text.Normal
        styleColor: Qt.rgba(0, 0, 0, 0.4)
        font.family: clock.family
        font.pixelSize: clock.timeSize
        font.weight: clock.timeWeight
        font.letterSpacing: -Math.round(clock.timeSize * 0.03)
    }

    Text {
        anchors.horizontalCenter: clock.centred ? parent.horizontalCenter : undefined
        topPadding: Math.round(clock.dateSize * 0.64)
        visible: clock.showDate
        text: clock.aside === ""
            ? clock.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
            : clock.now.toLocaleDateString(Qt.locale(), Locale.LongFormat) + " · " + clock.aside
        textFormat: Text.PlainText
        color: clock.dateInk
        style: clock.raised ? Text.Raised : Text.Normal
        styleColor: Qt.rgba(0, 0, 0, 0.4)
        font.family: clock.family
        font.pixelSize: clock.dateSize
        font.weight: Font.Light
    }
}
