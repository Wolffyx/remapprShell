pragma Singleton

// Layered configuration with live reload.
//
//   1 defaults   shipped, complete, read-only
//   2 profile    the user's file -- a SPARSE delta against the defaults
//   3 runtime    in-memory only, never persisted
//
// `merged` is the union, recomputed whenever any layer changes. Reading config
// anywhere in the shell means binding to `merged` (or `value()`), so a file
// edit propagates without a restart.
//
// The profile file is kept sparse on purpose: it should contain only what the
// user actually changed, so upgrading the defaults moves everything the user
// never touched. Writing a fully-materialised config back would freeze today's
// defaults into their file forever.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.system

QtObject {
    id: root

    // ---- state --------------------------------------------------------

    readonly property string profile: "default"

    property var defaults: ({})
    property var profileData: ({})
    property var runtime: ({})

    readonly property var merged: Obj.deepMerge(root.defaults, root.profileData, root.runtime)

    readonly property bool defaultsLoaded: Object.keys(root.defaults).length > 0

    // Writes are blocked while the profile file is unparseable. Without this,
    // a typo in the user's JSON plus one slider drag would overwrite their
    // whole file with a config built from defaults -- silently destroying the
    // edits they were in the middle of making.
    property bool writable: true
    property string lastError: ""

    signal changed
    signal writeBlocked(string reason)

    // ---- reading ------------------------------------------------------

    function value(path, fallback) {
        return Obj.get(root.merged, path, fallback);
    }

    function defaultValue(path, fallback) {
        return Obj.get(root.defaults, path, fallback);
    }

    // True when the user has overridden this path, i.e. it is present in the
    // profile layer. The settings GUI uses this to show a "reset" affordance.
    function isOverridden(path) {
        return Obj.has(root.profileData, path);
    }

    // ---- writing ------------------------------------------------------

    // Sets a value, keeping the profile sparse: if the new value equals the
    // shipped default, the key is removed instead of written.
    function set(path, value) {
        if (!root.writable) {
            root.writeBlocked(root.lastError);
            Log.warn("config", `refusing to write ${path}: ${root.lastError}`);
            return false;
        }

        const isDefault = Obj.deepEqual(value, Obj.get(root.defaults, path, undefined));
        root.profileData = isDefault ? Obj.unset(root.profileData, path)
                                     : Obj.set(root.profileData, path, value);
        root._scheduleWrite();
        return true;
    }

    function reset(path) {
        if (!root.writable) {
            root.writeBlocked(root.lastError);
            return false;
        }
        root.profileData = Obj.unset(root.profileData, path);
        root._scheduleWrite();
        return true;
    }

    // Runtime overrides sit above the profile and are never persisted. Used for
    // things like a temporary preview while dragging a slider.
    function setRuntime(path, value) {
        root.runtime = Obj.set(root.runtime, path, value);
    }

    function clearRuntime() {
        root.runtime = ({});
    }

    // ---- persistence --------------------------------------------------

    // Counts writes we initiated. The file watcher compares against it to tell
    // our own save from an external edit.
    property int _writeEpoch: 0
    property string _lastWritten: ""

    // ensureDir runs as a detached process, so the write has to wait for the
    // directory to exist. A short delay is enough and keeps this off the
    // startup path.
    readonly property Timer _seedTimer: Timer {
        interval: 150
        onTriggered: {
            root._writeEpoch++;
            root._profileView.setText(JSON.stringify({ schemaVersion: Migrations.currentVersion }, null, 4) + "\n");
        }
    }

    readonly property Timer _writeTimer: Timer {
        interval: 250   // coalesce slider drags into one write
        onTriggered: root._flush()
    }

    function _scheduleWrite() {
        root.changed();
        root._writeTimer.restart();
    }

    function _flush() {
        if (!root.writable)
            return;

        // Re-read before writing. If the file changed underneath us since our
        // last write, the user hand-edited it while the settings GUI was open;
        // reapply our delta onto their current content rather than clobbering it.
        const onDisk = root._parseProfile(root._profileView.text());
        if (onDisk.ok && !Obj.deepEqual(onDisk.data, root._lastParsed)) {
            Log.info("config", "profile changed on disk; merging our delta onto it");
            root.profileData = Obj.deepMerge(onDisk.data, root.profileData);
        }

        const out = Object.assign({ schemaVersion: Migrations.currentVersion }, root.profileData);
        const text = JSON.stringify(out, null, 4) + "\n";

        root._lastWritten = text;
        root._writeEpoch++;
        root._profileView.setText(text);
    }

    // ---- loading ------------------------------------------------------

    property var _lastParsed: ({})

    function _parseProfile(text) {
        if (!text || text.trim().length === 0)
            return { ok: true, data: {} };
        try {
            const parsed = JSON.parse(text);
            if (!Obj.isPlainObject(parsed))
                return { ok: false, error: "top level of the config must be an object" };
            return { ok: true, data: parsed };
        } catch (e) {
            return { ok: false, error: String(e) };
        }
    }

    function _onProfileText(text) {
        const res = root._parseProfile(text);

        if (!res.ok) {
            // Keep serving the last good config. A broken file must not blank
            // the user's desktop, and must not be overwritten.
            root.writable = false;
            root.lastError = res.error;
            Log.error("config", `${root._profileView.path}: ${res.error}`);
            Log.error("config", "writes are blocked until the file parses");
            return;
        }

        const data = Obj.clone(res.data);
        const version = typeof data.schemaVersion === "number" ? data.schemaVersion : Migrations.currentVersion;
        delete data.schemaVersion;

        if (Migrations.needsMigration(version) || version > Migrations.currentVersion) {
            const m = Migrations.migrate(data, version);
            if (!m.ok) {
                root.writable = false;
                root.lastError = m.error;
                Log.error("config", m.error);
                return;
            }
            root.profileData = m.config;
            root._lastParsed = Obj.clone(m.config);
            root.writable = true;
            root.lastError = "";
            root._scheduleWrite();   // persist the migrated shape
            root.changed();
            return;
        }

        root.profileData = data;
        root._lastParsed = Obj.clone(data);
        root.writable = true;
        root.lastError = "";
        Log.info("config", `profile loaded (${Object.keys(data).length} top-level override(s))`);
        root.changed();
    }

    readonly property FileView _defaultsView: FileView {
        path: Paths.defaultsFile
        watchChanges: true
        printErrors: false

        onLoaded: {
            try {
                root.defaults = JSON.parse(text());
                Log.info("config", `defaults loaded from ${path}`);
                root.changed();
            } catch (e) {
                // Shipped defaults failing to parse is a packaging bug, not a
                // user error, so it is loud.
                Log.error("config", `shipped defaults are invalid JSON: ${e}`);
            }
        }

        onLoadFailed: err => {
            Log.error("config", `cannot read shipped defaults at ${path} (error ${err})`);
        }

        // watchChanges reports that the file changed; it does not re-read it.
        // Without an explicit reload the shell would keep serving whatever it
        // read at startup, which is the opposite of live config.
        onFileChanged: reload()
    }

    readonly property FileView _profileView: FileView {
        path: Paths.profileConfigFile(root.profile)
        watchChanges: true
        atomicWrites: true
        printErrors: false

        onLoaded: root._onProfileText(text())

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                // Normal on a fresh install: no overrides yet.
                //
                // Seed the file rather than just carrying on. FileView's watcher
                // only follows a path that exists, so without a file here a
                // profile created later would never be noticed -- which on a
                // fresh install is every profile. Seeding also answers "where do
                // I configure this?" with a real path.
                Log.info("config", "no profile file yet; creating one");
                root.profileData = ({});
                root._lastParsed = ({});
                root.writable = true;
                Fs.ensureDir(Paths.profileDir(root.profile));
                root._seedTimer.restart();
                root.changed();
            } else {
                root.writable = false;
                root.lastError = `cannot read ${path} (error ${err})`;
                Log.error("config", root.lastError);
            }
        }

        onSaveFailed: err => {
            root.lastError = `cannot write ${path} (error ${err})`;
            Log.error("config", root.lastError);
        }

        onFileChanged: reload()

        // Re-read after our own write too: it re-establishes the watch when the
        // file was created rather than modified, which is the fresh-install
        // case where no watch could have been attached at startup.
        onSaved: reload()
    }
}
