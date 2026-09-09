pragma Singleton

// Structured logging. Lands in the systemd journal for the unit, which is what
// `rmpr doctor` and the crash reporter read, so the format is kept stable and
// greppable rather than pretty.
//
// Deliberately free of Quickshell imports: `core` is the bottom of the
// dependency ladder and depends on nothing, which also makes everything above
// it testable outside a running shell. Reading the environment is the platform
// layer's job, so the composition root sets `debugEnabled` at startup.

import QtQuick

QtObject {
    id: root

    property bool debugEnabled: false

    function _emit(level, scope, msg) {
        console.log(`[${level}] ${scope}: ${msg}`);
    }

    function debug(scope, msg) { if (root.debugEnabled) root._emit("debug", scope, msg); }
    function info(scope, msg)  { root._emit("info", scope, msg); }
    function warn(scope, msg)  { root._emit("warn", scope, msg); }
    function error(scope, msg) { root._emit("error", scope, msg); }
}
