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

    // What the launcher has been used to open, and when. State rather than
    // configuration: nobody would type it, and losing it costs a few days of
    // learning rather than a setting.
    readonly property string launcherUsageFile: `${root.stateDir}/launcher-usage.json`

    // The last forecast fetched, with the time it was fetched at. State, and
    // a cache: it exists so a restart draws the weather at once instead of an
    // empty card, and losing it costs one request.
    readonly property string weatherCacheFile: `${root.stateDir}/weather.json`

    // Images that were copied, kept as files because a clipboard picture is
    // megabytes and the history holds several. Written by the clipboard
    // watcher, deleted as entries fall off the end of the history, and gone
    // entirely when the history is cleared.
    readonly property string clipboardDir: `${root.stateDir}/clipboard`

    // Written once the first-run wizard has been through. It lives in state
    // rather than in the profile because "have you seen this window" is ours to
    // remember, not a setting the user would ever want to type.
    //
    // It is not on its own enough to decide a first run, and this file used to
    // say it was. The state directory is what a restore point rolls back, so
    // the marker can go missing on a machine configured for months -- see
    // FirstRun, which reads this one alongside the configuration and takes
    // both answers before deciding.
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
