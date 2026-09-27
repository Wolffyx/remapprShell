/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The accessible style's choices along the top: text size, contrast,
    captions, the on-screen keyboard and reduce motion, as first-class
    controls rather than a menu. Wrapped onto a second line when the text is
    large enough to need one.

    The choices are the style's; this draws them as they stand and says
    which was pressed, and the style makes the change and says it aloud.
*/
pragma ComponentBehavior: Bound

import QtQuick

Flow {
    id: bar

    required property var ui
    required property AccessibleLook look

    // The choices as they stand.
    property real size: 1.2
    property string contrast: "high"
    property bool captions: true
    property bool reduceMotion: false

    signal sizeChosen(real value, string label)
    signal contrastChosen(string value, string label)
    signal captionsToggled
    signal keyboardToggled
    signal motionToggled

    component Choice: AccessibleChoice {
        ui: bar.ui
        look: bar.look
    }

    spacing: Math.round(28 * bar.look.s)

    Row {
        spacing: Math.round(10 * bar.look.s)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Text size"
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: Math.round(17 * bar.look.s)
            font.weight: Font.Medium
            color: bar.look.sub
            Accessible.ignored: true
        }

        Repeater {
            model: [[1, "100%"], [1.2, "120%"], [1.4, "140%"]]

            Choice {
                required property var modelData
                label: modelData[1]
                on: Math.abs(bar.size - modelData[0]) < 0.01
                description: "Text size. Lasts for this lock only."
                onActivated: bar.sizeChosen(modelData[0], modelData[1])
            }
        }
    }

    Row {
        spacing: Math.round(10 * bar.look.s)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Contrast"
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: Math.round(17 * bar.look.s)
            font.weight: Font.Medium
            color: bar.look.sub
            Accessible.ignored: true
        }

        Repeater {
            model: [["standard", "Standard"], ["high", "High"]]

            Choice {
                required property var modelData
                label: modelData[1]
                on: bar.contrast === modelData[0]
                description: "Contrast. Lasts for this lock only."
                onActivated: bar.contrastChosen(modelData[0], modelData[1])
            }
        }
    }

    Row {
        spacing: Math.round(10 * bar.look.s)

        Choice {
            isSwitch: true
            glyph: "closed_caption"
            label: "Captions"
            on: bar.captions
            description: "Shows what this screen announces, along the bottom. Lasts for this lock only."
            onActivated: bar.captionsToggled()
        }

        Choice {
            isSwitch: true
            visible: bar.ui.keyboardAvailable
            glyph: "keyboard"
            label: "Keyboard"
            on: bar.ui.keyboardShown
            description: "Shows or hides the on-screen keyboard."
            onActivated: bar.keyboardToggled()
        }

        Choice {
            isSwitch: true
            glyph: "animation"
            label: "Reduce motion"
            on: bar.reduceMotion
            description: "Stops the clock rolling and the fades. Lasts for this lock only."
            onActivated: bar.motionToggled()
        }
    }
}
