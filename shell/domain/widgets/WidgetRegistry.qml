pragma Singleton

// Knows every widget that exists, built-in or installed by the user.
//
// Built-ins and third-party widgets have an identical manifest shape and go
// through the same code path. Keeping one path means the third-party case is
// exercised constantly by the built-ins rather than only when someone reports
// it broken.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.platform.system

QtObject {
    id: root

    // The manifest format this build understands. A widget declaring a newer
    // apiVersion is refused rather than half-loaded.
    readonly property int apiVersion: 1

    // Third-party widgets are skipped entirely in safe mode: it is the way back
    // in when a plugin has made the shell unusable, so it must not depend on
    // any plugin behaving well enough to be disabled individually.
    readonly property bool safeMode: Env.safeMode()

    // id -> manifest
    property var builtins: ({})
    property var userWidgets: ({})

    readonly property var all: Object.assign({}, root.builtins, root.userWidgets)

    property bool builtinsLoaded: false
    property bool userScanned: false
    readonly property bool ready: root.builtinsLoaded && root.userScanned

    signal changed

    function manifest(id) {
        return root.all[id] ?? null;
    }

    function exists(id) {
        return !!root.all[id];
    }

    function isBuiltin(id) {
        return !!root.builtins[id];
    }

    // Where a widget's QML lives, as a resolvable URL.
    function entryUrl(id) {
        const m = root.manifest(id);
        if (!m)
            return "";
        const entry = m.renderers?.quickshell?.entry;
        if (!entry)
            return "";   // widget has no Quickshell renderer
        // Quickshell.shellPath resolves against the shell root, so this is
        // correct both when running from the repo and when installed. A plain
        // Qt.resolvedUrl would return Quickshell's internal qs:@/ scheme, which
        // is not a filesystem path.
        return root.isBuiltin(id)
            ? `file://${Quickshell.shellPath(`widgets/${id}/${entry}`)}`
            : `file://${Paths.userWidgetsDir}/${id}/${entry}`;
    }

    function supportsRenderer(id, renderer) {
        return !!root.manifest(id)?.renderers?.[renderer];
    }

    // Widgets the given renderer cannot draw. Drives the warning shown before
    // switching renderers, so the user is told what they will lose rather than
    // discovering it afterwards.
    function unsupportedBy(renderer, ids) {
        return (ids ?? []).filter(id => root.exists(id) && !root.supportsRenderer(id, renderer));
    }

    // The default value for every key the manifest declares. These are the
    // per-widget defaults -- the shipped shell.json does not repeat them, so a
    // widget's defaults live with the widget.
    function configDefaults(id) {
        const schema = root.manifest(id)?.config ?? {};
        const out = {};
        for (const key of Object.keys(schema)) {
            if ("default" in schema[key])
                out[key] = schema[key].default;
        }
        return out;
    }

    function _accept(manifest, source) {
        if (!manifest || typeof manifest.id !== "string" || manifest.id.length === 0) {
            Log.warn("widgets", `${source}: manifest has no id; ignoring`);
            return null;
        }
        const declared = manifest.apiVersion ?? 1;
        if (declared > root.apiVersion) {
            Log.warn("widgets", `${source}: widget '${manifest.id}' needs manifest apiVersion ${declared}, this build supports ${root.apiVersion}`);
            return null;
        }
        return manifest;
    }

    // ---- built-ins: one generated index, read once ---------------------

    readonly property FileView _indexView: FileView {
        path: Quickshell.shellPath("widgets/index.json")
        printErrors: false

        onLoaded: {
            const out = {};
            try {
                for (const m of (JSON.parse(text()).widgets ?? [])) {
                    const ok = root._accept(m, "index.json");
                    if (ok)
                        out[ok.id] = ok;
                }
            } catch (e) {
                Log.error("widgets", `built-in widget index is invalid: ${e}`);
            }
            root.builtins = out;
            root.builtinsLoaded = true;
            Log.info("widgets", `${Object.keys(out).length} built-in widget(s)`);
            root.changed();
        }

        onLoadFailed: {
            Log.error("widgets", "built-in widget index missing; run scripts/gen-widget-index.sh");
            root.builtinsLoaded = true;
            root.changed();
        }
    }

    // ---- user widgets: one process, not one per widget -----------------

    readonly property Process _scan: Process {
        // A single process emitting every manifest as one JSON array. Spawning
        // one per widget turns a directory of plugins into a directory of
        // process launches on the startup path, and invites shell-quoting bugs
        // on paths the user controls.
        command: ["bash", "-c", `
            dir="$1"
            [ -d "$dir" ] || { echo '[]'; exit 0; }
            first=1
            printf '['
            for m in "$dir"/*/widget.json; do
                [ -e "$m" ] || continue
                id=$(basename "$(dirname "$m")")
                [ $first -eq 1 ] || printf ','
                first=0
                printf '{"__id":"%s","__manifest":' "$id"
                cat "$m"
                printf '}'
            done
            printf ']'
        `, "bash", Paths.userWidgetsDir]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                try {
                    for (const row of JSON.parse(text)) {
                        // The directory name wins over whatever the manifest
                        // claims: the loader resolves paths from it, so a
                        // mismatched id yields a widget that can be configured
                        // but never loaded.
                        const m = Object.assign({}, row.__manifest, { id: row.__id, builtin: false });
                        const ok = root._accept(m, `${Paths.userWidgetsDir}/${row.__id}`);
                        if (ok)
                            out[ok.id] = ok;
                    }
                } catch (e) {
                    Log.warn("widgets", `could not read user widgets: ${e}`);
                }
                root.userWidgets = out;
                root.userScanned = true;
                if (Object.keys(out).length > 0)
                    Log.info("widgets", `${Object.keys(out).length} user widget(s)`);
                root.changed();
            }
        }
    }

    function rescan() {
        if (root.safeMode) {
            Log.warn("widgets", "safe mode: third-party widgets are not loaded");
            root.userWidgets = ({});
            root.userScanned = true;
            root.changed();
            return;
        }
        root._scan.running = true;
    }

    Component.onCompleted: root.rescan()
}
