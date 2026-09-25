pragma Singleton

// Schema migrations.
//
// A profile file records the schemaVersion it was written against. When the
// shipped schema moves ahead, each migration between the two versions runs in
// order. Without this, an update that changes the config shape silently breaks
// every existing install -- so the harness exists from the first version, even
// though there is nothing to migrate yet.
//
// A migration is a pure function: (sparseProfileObject) -> sparseProfileObject.
// It must tolerate missing keys, because the profile is a sparse delta and may
// contain almost nothing.

import QtQuick
import qs.core
import qs.domain.config.steps

QtObject {
    id: root

    // The version the shipped defaults are written against. Bump this in the
    // same commit that changes the config shape, and add the matching entry
    // below.
    readonly property int currentVersion: 2

    // Keyed by the version being migrated *to*. The body of each is in
    // MigrationSteps, where the tests can reach it; the keys stay here,
    // because this is where scripts/update.sh reads them from.
    //   2: obj => Obj.set(obj, "panel.thickness", ...)
    readonly property var steps: ({
        // fuzzel and rofi became the custom command they always were.
        2: obj => MigrationSteps.toVersion2(obj)
    })

    function needsMigration(version) {
        return version < root.currentVersion;
    }

    // Returns { ok, version, config, error }.
    function migrate(config, fromVersion) {
        let obj = Obj.clone(config);
        let version = fromVersion;

        if (version > root.currentVersion) {
            return {
                ok: false,
                version: version,
                config: obj,
                error: `config schemaVersion ${version} is newer than this build supports (${root.currentVersion}); refusing to downgrade it`
            };
        }

        while (version < root.currentVersion) {
            const next = version + 1;
            const step = root.steps[next];
            if (!step) {
                return {
                    ok: false,
                    version: version,
                    config: obj,
                    error: `no migration registered for schemaVersion ${version} -> ${next}`
                };
            }
            try {
                obj = step(obj);
            } catch (e) {
                return {
                    ok: false,
                    version: version,
                    config: obj,
                    error: `migration ${version} -> ${next} threw: ${e}`
                };
            }
            version = next;
            Log.info("config", `migrated profile to schemaVersion ${version}`);
        }

        return { ok: true, version: version, config: obj, error: "" };
    }
}
