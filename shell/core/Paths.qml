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

    // Written once the first-run wizard has been through. It lives in state
    // rather than in the profile because "have you seen this window" is ours to
    // remember, not a setting the user would ever want to type -- and because a
    // profile with no overrides in it is a perfectly ordinary thing to have, so
    // an empty config cannot be the signal.
    readonly property string wizardDoneFile: `${root.stateDir}/wizard-done`

    // Widgets the user installed, deliberately outside the Quickshell config
    // directory, which belongs to the shell and is replaced by an update.
    //
    // (This used to say Quickshell reloads on any change beneath that
    // directory. Measured on 2026-09-11, it does not: it reloads for files
    // the config imported when it loaded, and not for a widget's own files,
    // which are loaded later by a Loader, nor for a singleton only such a
    // widget uses. `rmpr reload` is for those.)
    readonly property string userWidgetsDir: `${Branding.dataDir}/widgets`

    // A filesystem path as a URL.
    //
    // Qt resolves a bare path against the base URL of the component that uses
    // it, and for a type that lives in a module that base is inside qrc: -- so
    // an absolute path handed to an Image arrived as "qrc:/home/..." and could
    // not be opened. A screenshot notification showed a blank icon for exactly
    // this reason, its path having come straight off the bus.
    //
    // Each segment is encoded separately, so a file in a directory with a
    // space in its name is still a valid URL. Anything that is not an absolute
    // path -- a theme icon name, a URL that already has a scheme -- is handed
    // back untouched.
    function fileUrl(path) {
        const s = String(path ?? "");
        if (!s.startsWith("/"))
            return s;
        return "file://" + s.split("/").map(encodeURIComponent).join("/");
    }

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
