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

    // Branded names, so callers never build an env var from the slug.
    function safeMode() {
        return root.flag(Branding.safeModeVar);
    }

    function debug() {
        return root.flag(Branding.debugVar);
    }
}
