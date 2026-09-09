pragma ComponentBehavior: Bound

// Keeps one MonitorConfig per connected output.
//
// Variants rebuilds the set when monitors change, so hotplug is handled by the
// same mechanism as everything else that is per screen.

import QtQuick
import Quickshell

Scope {
    Variants {
        model: Quickshell.screens

        MonitorConfig {
            required property var modelData
            screenName: modelData.name
        }
    }
}
