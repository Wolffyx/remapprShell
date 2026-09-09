pragma Singleton

// Structured logging. Lands in the systemd journal for the unit, which is what
// `rmpr doctor` and the crash reporter read, so the format is kept stable and
// greppable rather than pretty.

import Quickshell
import QtQuick

QtObject {
    id: root

    // Enabled by the branded debug env var, resolved at generation time.
    readonly property bool debugEnabled: Qt.application.arguments.indexOf("--debug") !== -1
                                         || Quickshell.env(Branding.debugVar) === "1"

    function _emit(level, scope, msg) {
        console.log(`[${level}] ${scope}: ${msg}`);
    }

    function debug(scope, msg) { if (root.debugEnabled) root._emit("debug", scope, msg); }
    function info(scope, msg)  { root._emit("info", scope, msg); }
    function warn(scope, msg)  { root._emit("warn", scope, msg); }
    function error(scope, msg) { root._emit("error", scope, msg); }
}
