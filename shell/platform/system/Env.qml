pragma Singleton

// Environment access.
//
// Lives in the platform layer so that domain code never reaches for the
// process environment directly -- which keeps domain logic runnable in tests,
// where there is no Quickshell process at all.

import QtQuick
import Quickshell
import qs.core

QtObject {
    id: root

    function string(name, fallback) {
        const v = Quickshell.env(name);
        return (v === undefined || v === null || v === "") ? (fallback ?? "") : v;
    }

    function flag(name) {
        return root.string(name, "") === "1";
    }

    function int(name, fallback) {
        const v = parseInt(root.string(name, ""), 10);
        return Number.isFinite(v) ? v : fallback;
    }

    // The XDG base directories, as the running session has them. KDE puts
    // its own files where these say at the moment it writes them, so a file
    // of KDE's is looked for here and not under a path baked in at install.
    function xdgConfigHome() {
        return root.string("XDG_CONFIG_HOME", `${root.string("HOME")}/.config`);
    }

    function xdgDataHome() {
        return root.string("XDG_DATA_HOME", `${root.string("HOME")}/.local/share`);
    }

    // Branded names, so callers never build an env var from the slug.
    function safeMode() {
        return root.flag(Branding.safeModeVar);
    }

    function debug() {
        return root.flag(Branding.debugVar);
    }
}
