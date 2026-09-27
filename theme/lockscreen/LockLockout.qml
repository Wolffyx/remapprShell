/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Too many attempts: how long until the account can be tried again.

    pam_faillock says it once, in words -- "(10 minutes left to unlock)" --
    and Unlock turns that into a moment. This counts down to it, at the top
    of every style, as the design draws it on all thirteen screens. It only
    ever draws: typing during a lockout still reaches PAM, which is what
    refuses it, and which keeps its own clock rather than this one.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: toast

    required property Unlock unlock
    property real unit: 1

    property double now: Date.now()
    readonly property double remaining: Math.max(0, toast.unlock.lockedUntil - toast.now)
    readonly property bool counting: toast.remaining > 0

    // Minutes while there are minutes, then seconds -- a ring labelled "10"
    // that meant seconds would be a lie for nine and a half minutes.
    readonly property string label: toast.remaining >= 60000
        ? Math.ceil(toast.remaining / 60000) + "m"
        : String(Math.ceil(toast.remaining / 1000))

    width: row.width + Math.round(32 * toast.unit)
    height: Math.round(72 * toast.unit)
    radius: Math.round(18 * toast.unit)
    color: Qt.rgba(10 / 255, 9 / 255, 8 / 255, 0.86)
    border.width: 1
    border.color: Qt.rgba(224 / 255, 120 / 255, 106 / 255, 0.45)

    // Faded in and out, and hidden only once the fade has finished. A
    // `visible` set from outside must keep that, or the fade out never
    // plays.
    opacity: toast.counting ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        // Until it has run out, and not a tick after.
        running: toast.unlock.lockedUntil > toast.now
        onTriggered: toast.now = Date.now()
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        x: Math.round(12 * toast.unit)
        spacing: Math.round(14 * toast.unit)

        LockRing {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(48 * toast.unit)
            height: width
            fraction: toast.unlock.lockedSpan > 0 ? toast.remaining / toast.unlock.lockedSpan : 0
            label: toast.label
            thickness: Math.round(5 * toast.unit)
            labelSize: Math.round(14 * toast.unit)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(2 * toast.unit)

            Text {
                text: "Too many attempts"
                textFormat: Text.PlainText
                color: "#f4efe8"
                font.family: "Rubik"
                font.pixelSize: Math.round(14 * toast.unit)
                font.weight: Font.Medium
            }

            Text {
                text: "Input paused · pam_faillock"
                textFormat: Text.PlainText
                color: "#b3aba1"
                font.family: "Rubik"
                font.pixelSize: Math.round(12.5 * toast.unit)
            }
        }
    }
}
