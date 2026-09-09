pragma Singleton

// Every path the shell reads or writes. Centralised so that a rename (which
// moves all of them at once) touches one file, and so nothing constructs a
// path by string-concatenating a directory somewhere far from here.

import QtQuick
import qs.core

QtObject {
    id: root

    // User-authored configuration. Never written by the installer.
    readonly property string configDir: Branding.configDir
    readonly property string profilesDir: `${root.configDir}/profiles`
    readonly property string stateFile: `${root.configDir}/state.json`

    // Shipped, read-only.
    readonly property string defaultsFile: `${Branding.dataDir}/config/defaults/shell.json`

    // Mutable runtime state: ledgers, snapshots, health. Never in configDir,
    // which belongs to the user.
    readonly property string stateDir: Branding.stateDir
    readonly property string widgetHealthFile: `${root.stateDir}/widget-health.json`
    readonly property string diagnosticsDir: `${root.stateDir}/diagnostics`

    // Widgets the user installed, deliberately outside the Quickshell config
    // directory: Quickshell reloads its entire config on any change beneath
    // that directory, so editing a plugin there would restart the whole shell.
    readonly property string userWidgetsDir: `${Branding.dataDir}/widgets`

    function profileDir(profile) {
        return `${root.profilesDir}/${profile}`;
    }

    function profileConfigFile(profile) {
        return `${root.profileDir(profile)}/shell.json`;
    }

    function monitorConfigFile(profile, output) {
        return `${root.profileDir(profile)}/monitors/${output}.json`;
    }
}
