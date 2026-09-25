/*
    SPDX-License-Identifier: GPL-3.0-or-later

    A battery running out behind a locked screen, said louder as it runs out.

    The design's 4d, drawn over every style rather than as one of its own,
    because a battery does not care which lock screen is up. Three steps:

    - **low**, at Plasma's own low level: a quiet pill at the top.
    - **critical**, at Plasma's critical level: a banner across the top, the
      edges reddening, and a button that hibernates now.
    - **hibernating**, at `hibernateAt`: a minute's countdown, then the
      session is hibernated -- saved to disk, so nothing is lost. Plugging in
      stops it, and so does saying so.

    The two levels are read from powerdevilrc rather than chosen here, so the
    lock screen and Plasma's power management agree about when a battery is
    low. Plasma has a critical-battery action of its own; `hibernateAt: 0`
    leaves it at that.

    Nothing here is drawn on a machine with no battery, or while plugged in.
*/
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.battery

Item {
    id: power

    required property var ui

    // For dev/preview/lock.sh only: { percent, pluggedIn, canHibernate } in
    // place of the real battery. With one set, nothing is ever hibernated.
    property var override: null

    readonly property real unit: power.ui.unit

    BatteryControlModel {
        id: battery
    }

    Settings {
        id: powerdevil
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/powerdevilrc"
        category: "BatteryManagement"
    }

    readonly property bool present: power.override ? true : battery.hasInternalBatteries
    readonly property int percent: power.override ? power.override.percent : battery.percent
    readonly property bool plugged: power.override ? !!power.override.pluggedIn : battery.pluggedIn

    // What the styles say about the battery, from this one model rather than
    // one of their own each -- so a preview's stand-in reaches every style
    // that draws a battery, not only this file. A stand-in has no time left
    // to report, and charges whenever it is plugged in and not full.
    readonly property double remainingMsec: power.override ? 0 : battery.remainingMsec
    readonly property double smoothedRemainingMsec: power.override ? 0 : battery.smoothedRemainingMsec
    readonly property bool charging: power.override ? power.plugged && power.percent < 100
                                                     : battery.state === BatteryControlModel.Charging
    readonly property bool full: power.override ? power.plugged && power.percent >= 100
                                                 : battery.state === BatteryControlModel.FullyCharged
    // Material Symbols' battery at this charge: none to six bars, full, or
    // charging.
    readonly property string glyph: power.plugged ? "battery_charging_full"
        : power.percent >= 95 ? "battery_full"
        : "battery_" + Math.max(0, Math.min(6, Math.floor(power.percent / 15))) + "_bar"

    readonly property int lowAt: Number(powerdevil.value("BatteryLowLevel", 10)) || 10
    readonly property int criticalAt: Number(powerdevil.value("BatteryCriticalLevel", 5)) || 5

    readonly property bool discharging: power.present && !power.plugged
    readonly property bool low: power.discharging && power.percent <= power.lowAt && power.percent > power.criticalAt
    readonly property bool critical: power.discharging && power.percent <= power.criticalAt
    readonly property bool canHibernate: power.override?.canHibernate ?? power.ui.session?.canHibernate ?? false
    readonly property bool hibernates: Options.hibernateAt > 0 && power.canHibernate

    // Set once the countdown has been answered -- by hibernating, or by the
    // person saying they have plugged in -- and cleared once the battery is
    // above the line again, or really is plugged in.
    property bool answered: false
    readonly property bool dying: power.critical && power.hibernates && power.percent <= Options.hibernateAt
        && !power.answered

    onPluggedChanged: if (power.plugged) power.answered = false
    onPercentChanged: if (power.percent > Options.hibernateAt) power.answered = false

    // --- the countdown ----------------------------------------------------

    readonly property int countdownMs: 60000
    property double deadline: 0
    property double now: Date.now()
    readonly property int secondsLeft: Math.max(0, Math.ceil((power.deadline - power.now) / 1000))

    onDyingChanged: {
        if (power.dying) {
            power.now = Date.now();
            power.deadline = power.now + power.countdownMs;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: power.dying
        onTriggered: {
            power.now = Date.now();
            if (power.now >= power.deadline)
                power.hibernate();
        }
    }

    function hibernate(): void {
        power.answered = true;
        if (power.override) {
            console.warn("preview: would hibernate now");
            return;
        }
        power.ui.session.hibernate();
    }

    function remaining(): string {
        const ms = power.remainingMsec;
        if (power.override || !ms || ms <= 0)
            return "";
        return "about " + LockText.duration(ms, false) + " left";
    }

    // --- critical: the edges redden ---------------------------------------

    Shape {
        anchors.fill: parent
        opacity: power.critical ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 800 } }

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: power.width / 2
                centerY: power.height / 2
                centerRadius: Math.max(power.width, power.height) * 0.62
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0.4; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(160 / 255, 40 / 255, 30 / 255, 0.45) }
            }
            startX: 0; startY: 0
            PathLine { x: power.width; y: 0 }
            PathLine { x: power.width; y: power.height }
            PathLine { x: 0; y: power.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // --- low: a pill ------------------------------------------------------

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(24 * power.unit)
        width: lowRow.width + Math.round(36 * power.unit)
        height: Math.round(42 * power.unit)
        radius: height / 2
        color: Qt.rgba(224 / 255, 201 / 255, 138 / 255, 0.14)
        border.width: 1
        border.color: Qt.rgba(224 / 255, 201 / 255, 138 / 255, 0.4)
        opacity: power.low ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        Row {
            id: lowRow
            anchors.centerIn: parent
            spacing: Math.round(10 * power.unit)

            SymbolText {
                anchors.verticalCenter: parent.verticalCenter
                symbol: "battery_3_bar"
                font.pixelSize: Math.round(19 * power.unit)
                color: "#e0c98a"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ["Battery low", power.percent + "%", power.remaining()].filter(p => p).join(" · ")
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: Math.round(15 * power.unit)
                color: "#e0c98a"
            }
        }
    }

    // --- critical: a banner -----------------------------------------------

    Rectangle {
        width: parent.width
        height: Math.round(76 * power.unit)
        color: "#e0c98a"
        y: power.critical ? 0 : -height
        visible: y > -height
        Behavior on y { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Math.round(56 * power.unit)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(14 * power.unit)

            SymbolText {
                anchors.verticalCenter: parent.verticalCenter
                symbol: "battery_alert"
                font.pixelSize: Math.round(26 * power.unit)
                color: "#211b0e"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: power.hibernates
                    ? "Plug in now. " + power.percent + "% left; this computer hibernates at " + Options.hibernateAt + "%."
                    : "Plug in now. " + power.percent + "% left."
                textFormat: Text.PlainText
                font.family: "Rubik"
                font.pixelSize: Math.round(18 * power.unit)
                font.weight: Font.Medium
                color: "#211b0e"
            }
        }

        PowerButton {
            anchors.right: parent.right
            anchors.rightMargin: Math.round(56 * power.unit)
            anchors.verticalCenter: parent.verticalCenter
            visible: power.canHibernate
            text: "Hibernate now"
            fill: "#211b0e"
            ink: "#e0c98a"
            onActivated: power.hibernate()
        }
    }

    // --- hibernating: the countdown ---------------------------------------

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(20 / 255, 6 / 255, 5 / 255, 0.72)
        opacity: power.dying ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        // Nothing underneath is pressed through it.
        MouseArea {
            anchors.fill: parent
            onPressed: power.ui.unlock.poke()
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.round(620 * power.unit)
            height: card.height + Math.round(80 * power.unit)
            radius: Math.round(28 * power.unit)
            color: "#1d1413"
            border.width: 1
            border.color: Qt.rgba(224 / 255, 120 / 255, 106 / 255, 0.5)

            Column {
                id: card

                anchors.centerIn: parent
                width: parent.width - Math.round(80 * power.unit)
                spacing: 0

                LockRing {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(120 * power.unit)
                    height: width
                    fraction: power.secondsLeft / (power.countdownMs / 1000)
                    label: String(power.secondsLeft)
                    thickness: Math.round(10 * power.unit)
                    labelSize: Math.round(40 * power.unit)
                    labelWeight: Font.Light
                    family: "Rubik"
                    track: Qt.rgba(1, 1, 1, 0.1)
                }

                Text {
                    width: parent.width
                    topPadding: Math.round(24 * power.unit)
                    horizontalAlignment: Text.AlignHCenter
                    text: "Hibernating in " + power.secondsLeft + " s"
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(30 * power.unit)
                    font.weight: Font.Medium
                    color: "#f4efe8"
                }

                Text {
                    width: parent.width
                    topPadding: Math.round(10 * power.unit)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "Battery at " + power.percent + "%. Your session is saved to disk first, so nothing is lost."
                    textFormat: Text.PlainText
                    font.family: "Rubik"
                    font.pixelSize: Math.round(16 * power.unit)
                    lineHeight: 1.3
                    color: "#cdc6be"
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: Math.round(28 * power.unit)
                    spacing: Math.round(12 * power.unit)

                    PowerButton {
                        text: "Hibernate now"
                        fill: "#e0786a"
                        ink: "#1d1413"
                        onActivated: power.hibernate()
                    }

                    PowerButton {
                        text: "I’ve plugged in"
                        fill: Qt.rgba(1, 1, 1, 0.1)
                        ink: "#f4efe8"
                        onActivated: power.answered = true
                    }
                }
            }
        }
    }

    component PowerButton: Rectangle {
        id: button

        property string text
        property color ink
        property color fill
        signal activated

        width: word.implicitWidth + Math.round(44 * power.unit)
        height: Math.round(48 * power.unit)
        radius: Math.round(14 * power.unit)
        color: button.fill
        opacity: hover.hovered ? 0.88 : 1

        Text {
            id: word
            anchors.centerIn: parent
            text: button.text
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: Math.round(15 * power.unit)
            font.weight: Font.Medium
            color: button.ink
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: button.activated() }
        Accessible.role: Accessible.Button
        Accessible.name: button.text
        Accessible.onPressAction: button.activated()
    }
}
