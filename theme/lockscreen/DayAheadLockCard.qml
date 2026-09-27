/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Where the day-ahead design has its battery and disk, in its two-up card:
    when this screen locked and how many passwords it has refused since,
    which the greeter does know, and the battery under them when there is
    one.
*/
pragma ComponentBehavior: Bound

import QtQuick

DayAheadCard {
    id: lock

    // The frame, for when it locked, what it has refused, and the battery.
    required property var ui

    readonly property LockPower battery: lock.ui.battery

    readonly property string lockedTime: lock.ui.lockedAt.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)

    readonly property string batteryLine: {
        const left = lock.colours.dur(Math.max(1, Math.round(lock.battery.remainingMsec / 60000)));
        if (lock.battery.plugged) {
            if (lock.battery.full)
                return "plugged in · full";
            if (lock.battery.charging)
                return lock.battery.remainingMsec > 0 ? "charging · full in " + left : "charging";
            return "plugged in · not charging";
        }
        return lock.battery.remainingMsec > 0 ? "on battery · " + left + " left" : "on battery";
    }

    component Caption: DayAheadCaption {
        colours: lock.colours
        unit: lock.unit
    }

    // The design's big number with a small note after it: "84% · 40 min to full".
    component Figure: Row {
        id: figure

        property string value: ""
        property string note: ""
        property color tint: lock.colours.ink

        width: parent?.width ?? 0
        spacing: lock.px(6)

        Text {
            id: figureValue

            text: figure.value
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: lock.px(22)
            color: figure.tint
        }

        Text {
            anchors.baseline: figureValue.baseline
            width: figure.width - figureValue.width - figure.spacing
            visible: figure.note !== ""
            elide: Text.ElideRight
            text: "· " + figure.note
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: lock.px(13)
            color: lock.colours.sub
        }
    }

    height: (batteryBody.visible ? batteryBody.y + batteryBody.height : lockGrid.y + lockGrid.height) + lock.px(22)

    Grid {
        id: lockGrid

        x: lock.px(24)
        y: lock.px(22)
        width: parent.width - lock.px(48)
        columns: 2
        columnSpacing: lock.px(20)
        rowSpacing: lock.px(18)

        readonly property int cell: Math.floor((lockGrid.width - lockGrid.columnSpacing) / 2)

        Column {
            width: lockGrid.cell
            spacing: lock.px(6)

            Caption {
                text: "LOCKED AT"
            }

            Figure {
                value: lock.lockedTime
            }
        }

        Column {
            width: lockGrid.cell
            spacing: lock.px(6)

            Caption {
                text: "REFUSED"
            }

            Figure {
                value: String(lock.ui.unlock.refusals)
                note: lock.ui.unlock.refusals === 1 ? "password" : "passwords"
                tint: lock.ui.unlock.refusals > 0 ? lock.colours.bad : lock.colours.ink
            }
        }
    }

    Column {
        id: batteryBody

        x: lock.px(24)
        y: lockGrid.y + lockGrid.height + lock.px(18)
        width: parent.width - lock.px(48)
        spacing: lock.px(6)
        visible: lock.battery.present

        Caption {
            text: "BATTERY"
        }

        Figure {
            value: lock.battery.percent + "%"
            note: lock.batteryLine
        }

        Rectangle {
            width: parent.width
            height: lock.px(4)
            radius: height / 2
            color: lock.colours.line

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, lock.battery.percent)) / 100
                height: parent.height
                radius: height / 2
                color: lock.battery.percent <= 15 && !lock.battery.plugged ? lock.colours.bad : "#7fb98a"
            }
        }
    }
}
