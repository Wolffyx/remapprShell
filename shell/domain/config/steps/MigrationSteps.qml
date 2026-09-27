pragma Singleton

// What each schema migration does, where the tests can load it.
//
// Migrations.qml lists the steps -- scripts/update.sh reads the list from
// there, and so the keys stay there -- but it sits in qs.domain.config beside
// ConfigStore, which needs a running shell, and a test that imported it would
// not load. A step rewrites somebody's profile, which is worth a test, so its
// body is here, pure, and Migrations calls it.

import QtQuick
import qs.core

QtObject {
    id: root

    // 2 -- fuzzel and rofi stop being launchers of their own (2026-09-24).
    //
    // They were two fixed command lines beside the custom command, which runs
    // any launcher at all, and nobody here used them. A profile that chose one
    // keeps it as the custom command it always was: the choice becomes
    // "custom", and `launcher.command` the command line it ran. There is one
    // custom command, so when a profile already has another -- or chose fuzzel
    // for the menu and rofi for the search -- the menu's choice keeps it, and
    // the other goes back to "auto": the built-in launcher, which opens,
    // rather than somebody else's program under the wrong name.
    readonly property var retiredLaunchers: ({
        fuzzel: ["fuzzel"],
        rofi: ["rofi", "-show", "drun"]
    })

    function toVersion2(config) {
        let out = Obj.clone(config ?? {});
        for (const key of ["launcher.provider", "launcher.searchProvider"]) {
            const was = String(Obj.get(out, key, ""));
            if (!Object.prototype.hasOwnProperty.call(root.retiredLaunchers, was))
                continue;
            const command = root.retiredLaunchers[was];
            // Empty is nothing set, an empty list, or an empty string from a
            // hand edit; anything else is somebody's own command, kept.
            const own = Obj.get(out, "launcher.command", []);
            if (String(own ?? "").length === 0) {
                out = Obj.set(out, "launcher.command", command);
                out = Obj.set(out, key, "custom");
            } else if (Obj.deepEqual(own, command)) {
                out = Obj.set(out, key, "custom");
            } else {
                out = Obj.set(out, key, "auto");
            }
        }
        return out;
    }
}
