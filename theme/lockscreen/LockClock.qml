/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The time, and the date under it.

    One timer, ticking once a second, shared by whichever style is drawn --
    the designs differ on size, weight and where the line breaks, not on what
    a clock is. Both lines are the locale's own: `ShortFormat` for the time
    so a machine set to twelve hours shows twelve, `LongFormat` for the date.

    The digits roll: each is a column of 0 to 9 behind a window one digit
    tall, and the column slides when the digit changes, as the design's
    turn 4 draws every clock. Anything that is not a digit -- the colon, a
    locale's AM -- is plain text beside them. `animated: false` keeps the
    columns and drops the slide, for the accessible style's reduced motion.

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

    // The digits slide when they change. Off for reduced motion.
    property bool animated: true

    // A Qt time format, for a style that wants seconds or a fixed 24 hours.
    // Empty is the locale's own short time.
    property string format: ""

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

    // The time as a string, for a style that wants to say it elsewhere too.
    readonly property string timeText: clock.format === ""
        ? clock.now.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
        : Qt.formatTime(clock.now, clock.format)

    // --- the time --------------------------------------------------------

    // One face for every digit column, with tabular figures so that a 1
    // takes the room an 8 does and the colon never moves.
    readonly property font timeFont: Qt.font({
        family: clock.family,
        pixelSize: clock.timeSize,
        weight: clock.timeWeight,
        features: { "tnum": 1 },
    })
    readonly property real tracking: -Math.round(clock.timeSize * 0.03)

    TextMetrics {
        id: digitMetrics
        font: clock.timeFont
        text: "0"
    }

    Row {
        anchors.horizontalCenter: clock.centred ? parent.horizontalCenter : undefined

        Repeater {
            model: clock.timeText.length

            Item {
                id: glyph

                required property int index
                readonly property string ch: clock.timeText.charAt(glyph.index)
                readonly property bool digit: glyph.ch >= "0" && glyph.ch <= "9"
                // Line height, not ascent: the column is a stack of whole lines.
                readonly property real step: digitMetrics.height

                width: (glyph.digit ? digitMetrics.advanceWidth : plain.implicitWidth) + clock.tracking
                height: glyph.step
                clip: glyph.digit

                Column {
                    visible: glyph.digit
                    y: glyph.digit ? -Number(glyph.ch) * glyph.step : 0

                    Behavior on y {
                        enabled: clock.animated
                        NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
                    }

                    Repeater {
                        model: 10

                        Text {
                            required property int index
                            height: glyph.step
                            text: String(index)
                            textFormat: Text.PlainText
                            color: clock.ink
                            style: clock.raised ? Text.Raised : Text.Normal
                            styleColor: Qt.rgba(0, 0, 0, 0.4)
                            font: clock.timeFont
                        }
                    }
                }

                Text {
                    id: plain
                    visible: !glyph.digit
                    text: glyph.digit ? "" : glyph.ch
                    textFormat: Text.PlainText
                    color: clock.ink
                    style: clock.raised ? Text.Raised : Text.Normal
                    styleColor: Qt.rgba(0, 0, 0, 0.4)
                    font: clock.timeFont
                }
            }
        }
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
