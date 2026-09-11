pragma Singleton

// The battery, and the power profile, as UPower and power-profiles-daemon see
// them.
//
// UPower's display device exists on every machine, battery or not; on a
// desktop it is a placeholder with nothing present. Only a present device of
// type Battery means there is a battery to show.

import QtQuick
import Quickshell.Services.UPower
import qs.domain.status.icons

QtObject {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: !!root.device && root.device.isPresent
                                    && root.device.type === UPowerDeviceType.Battery

    readonly property real level: StatusIcons.fraction(root.device?.percentage ?? 0)
    readonly property bool onBattery: UPower.onBattery
    readonly property bool charging: root.device?.state === UPowerDeviceState.Charging
                                     || root.device?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: root.device?.state === UPowerDeviceState.FullyCharged

    readonly property string stateLabel: root.charging ? "Charging"
                                       : root.full ? "Fully charged"
                                       : root.onBattery ? "On battery"
                                       : "Plugged in, not charging"

    readonly property string timeLabel: {
        if (root.charging) {
            const t = StatusIcons.duration(root.device?.timeToFull ?? 0);
            return t ? `${t} until full` : "";
        }
        if (root.onBattery) {
            const t = StatusIcons.duration(root.device?.timeToEmpty ?? 0);
            return t ? `${t} left` : "";
        }
        return "";
    }

    readonly property string icon: root.present ? StatusIcons.batteryIcon(root.level, root.charging)
                                                : "battery-missing"

    readonly property string profile: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "PowerSaver";
        case PowerProfile.Performance:
            return "Performance";
        default:
            return "Balanced";
        }
    }

    // Performance is offered only where the hardware has one; power-profiles-
    // daemon says so rather than failing the switch.
    readonly property var profiles: PowerProfiles.hasPerformanceProfile
        ? ["PowerSaver", "Balanced", "Performance"]
        : ["PowerSaver", "Balanced"]

    function setProfile(name) {
        PowerProfiles.profile = name === "PowerSaver" ? PowerProfile.PowerSaver
                              : name === "Performance" ? PowerProfile.Performance
                              : PowerProfile.Balanced;
    }

    function summary() {
        return {
            present: root.present,
            level: root.level,
            state: root.stateLabel,
            time: root.timeLabel,
            onBattery: root.onBattery,
            profile: root.profile,
            profiles: root.profiles,
            icon: root.icon
        };
    }
}
