/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The accessible style's cards under the clock, each true of this machine:
    the battery, when the lock started, the keyboard layout when there is
    more than one, and what is playing. The design's weather and next event
    are not among them; the greeter cannot know either.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.mpris as Mpris

Column {
    id: facts

    required property var ui
    required property AccessibleLook look

    readonly property LockPower battery: facts.ui.battery

    component Fact: AccessibleFact {
        ui: facts.ui
        look: facts.look
    }

    spacing: Math.round(14 * facts.look.s)

    Fact {
        visible: facts.battery.present
        glyph: facts.battery.plugged ? "battery_charging_full" : "battery_5_bar"
        text: {
            const b = facts.battery;
            const left = b.smoothedRemainingMsec > 0 ? LockText.duration(b.smoothedRemainingMsec, true) : "";
            if (b.plugged && b.percent < 100)
                return `Battery ${b.percent}%, charging` + (left ? ` · full in ${left}` : "");
            if (b.plugged)
                return `Battery ${b.percent}%, plugged in`;
            return `Battery ${b.percent}%` + (left ? ` · about ${left} left` : "");
        }
    }

    Fact {
        glyph: "lock_clock"
        text: "Locked at " + facts.ui.lockedAt.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
    }

    Fact {
        visible: LockKeys.layouts.length > 1
        pressable: true
        glyph: "keyboard"
        text: "Keyboard layout: " + LockKeys.layoutName
        description: "Switches to the next keyboard layout."
        onActivated: LockKeys.nextLayout()
    }

    Repeater {
        model: LockKeys.players

        Fact {
            required property var model
            visible: facts.ui.setting("showMediaControls", true) && model.track.length > 0
            glyph: model.playbackStatus === Mpris.PlaybackStatus.Playing ? "graphic_eq" : "music_note"
            text: (model.playbackStatus === Mpris.PlaybackStatus.Playing ? "Playing " : "Paused: ")
                + model.track + (model.artist ? ` · ${model.artist}` : "")
        }
    }
}
