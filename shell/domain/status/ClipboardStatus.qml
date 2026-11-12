pragma Singleton

// Clipboard history: Plasma's Klipper when it is running, and a history of
// our own when it is not.
//
// Klipper is not a program of its own in Plasma 6. It lives in libklipper,
// and the only thing on the system that loads it is the clipboard applet's
// QML plugin (org.kde.plasma.private.clipboard); plasmashell does not link it.
// So Klipper exists exactly while a clipboard applet is loaded somewhere --
// which under our renderer is never, because the shell package draws no
// system tray. No Klipper: no history, and Meta+V does nothing.
//
// When org.kde.klipper is on the bus this is a view of its history and
// changes nothing about how Klipper works. When it is not, this keeps a
// history of its own from `wl-paste --watch`: text in memory, and images as
// files in this shell's own cache directory -- never anything a password
// manager marks secret.
//
// Images are the one thing written to disk, and only because there is nowhere
// else to put them: a clipboard picture is megabytes, and a shell that holds
// several of them in QML grows all day. They live under the state directory,
// are deleted as they fall off the end of the history, and the whole lot goes
// when the history is cleared. That is the difference between "copied an
// image" working and an image being an entry you can see and not choose,
// which is what this used to be.
//
// Two ways of restoring Klipper itself were rejected. Loading its private QML
// plugin here would start a second Klipper whenever plasmashell has one too,
// two clipboard managers acting on one clipboard and both saving history to
// the same file. Opening Plasma's clipboard applet with plasmawindowed does
// the same thing in another process.
//
// Pinned entries of ours are written down too while `clipboard.keepPins` is
// on (the default), to Paths.clipboardPinsFile, private to the user, so a pin
// outlives a restart; turning the setting off removes the file. Nothing
// unpinned is ever written.
//
// So the image file of an unpinned entry outlives its entry when the shell
// stops or reloads, and nothing could show it again. Once the pins are back
// at start, the files an earlier run left are deleted: the watcher's own
// names only, older than this start, and not a pin's
// (ClipboardHistory.clipboardStale).
//
// Choosing an entry puts it on the clipboard with wl-copy, through stdin, in
// both cases: Klipper sees the change and moves the entry to the top, and the
// text is never in a process's arguments, where any local user could read it
// from /proc.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.kde
import qs.platform.system
import qs.domain.config
import qs.domain.status.icons

QtObject {
    id: root

    // How much of our own history is kept. Klipper keeps its own count.
    readonly property int limit: 50

    // Where a copied image is written. Named here rather than reached for
    // inside the watcher's command, where it sits in a string qmllint cannot
    // see through.
    readonly property string imageDir: Paths.clipboardDir

    // Which history to show. Plasma's Klipper keeps one whenever a clipboard
    // applet is loaded anywhere -- including in a Plasma panel running beside
    // this shell. Its DBus interface hands out text and nothing else, so its
    // history is read from its own database instead where that is the one
    // this reads (Plasma 6's history3.sqlite, version 3): its images are
    // files there, and choosing one copies Klipper's own file back -- one copy
    // of each picture on the machine, not two. Where the database is not
    // that one, its DBus text list is shown, and an image in it can be seen
    // and not chosen.
    //
    // So this is a setting rather than a rule, and ours is the default. Both
    // histories can exist at once without fighting: neither writes to the
    // other, and choosing an entry only puts it back on the clipboard, which
    // is a thing any application may do.
    //
    //   own     this shell's own history: text, and images you can choose
    //   plasma  Klipper's, always -- one history on the machine
    //   auto    Klipper's while it is running, ours when it is not
    readonly property string wanted: ConfigStore.value("clipboard.history", "own")

    // Whether Klipper is on the bus. Checked at start and whenever the name
    // changes hands, which is what a renderer switch does.
    property bool klipperPresent: false
    property bool checked: false

    readonly property bool klipper: root.klipperPresent
        && (root.wanted === "plasma" || (root.wanted === "auto" && root.klipperPresent))

    readonly property string source: root.klipper ? "klipper" : "own"

    property var klipperEntries: []
    property var ownEntries: []

    // [{ text, image, path?, width?, height?, pinned?, time? }]: the pinned
    // first, then newest first. See ClipboardHistory.
    readonly property var entries: root.klipper ? root.klipperEntries : root.ownEntries

    // Put an entry back on the clipboard. Text goes through stdin, so it is
    // never in a process's arguments where any local user could read it from
    // /proc; an image is a file, and wl-copy reads it the same way. See
    // Clipboard.
    function pick(entry) {
        if (!entry)
            return;
        if (entry.image) {
            if (!entry.path)
                return;
            root._picked = root.klipper ? "" : entry.path;
            root._pickedAt = Date.now();
            Clipboard.copyFile(entry.path, "image/png");
            return;
        }
        if (!entry.text)
            return;
        Clipboard.copyText(entry.text);
    }

    // The picture last put back on the clipboard from the history, and when.
    // It comes back through the image watcher as a new file, which replaces
    // it rather than standing beside it as a second copy of the same thing.
    property string _picked: ""
    property real _pickedAt: 0

    // Whether choosing this entry would do anything. An image has a file to
    // copy -- ours, or Klipper's when its database was read -- or it is only
    // shown: Klipper's DBus list names a picture and offers no way to get it.
    function pickable(entry) {
        return !!entry && (entry.image ? !!entry.path : String(entry.text ?? "").length > 0);
    }

    // Whether entries can be pinned and removed one at a time. Ours can;
    // Klipper's DBus interface offers neither, so in its history the
    // controls are not shown rather than shown and doing nothing.
    readonly property bool editable: !root.klipper

    // Clears the history. Ours keeps what is pinned -- it is pinned so that
    // it stays -- and Klipper's is Klipper's to clear, all of it.
    function clear() {
        if (root.klipper) {
            Dbus.send("org.kde.klipper", "/klipper", "org.kde.klipper.klipper", "clearClipboardHistory");
            return;
        }
        root._keep(ClipboardHistory.clipboardClear(root.ownEntries));
    }

    // Pins an entry of ours, or unpins it: a pinned entry stays at the top,
    // is never pushed off the end, and survives clearing.
    function togglePin(entry) {
        if (!root.editable || !entry)
            return;
        root.ownEntries = ClipboardHistory.clipboardTogglePin(root.ownEntries, entry);
    }

    // Takes one entry of ours out of the history, and its file with it.
    function remove(entry) {
        if (!root.editable || !entry)
            return;
        root._keep(ClipboardHistory.clipboardRemove(root.ownEntries, entry));
    }

    // The files of entries that have fallen out of the history. Deleted with
    // `rm -f` on exactly the paths this shell wrote, never a directory and
    // never a pattern.
    function _forget(paths) {
        if (!paths || paths.length === 0)
            return;
        remover.command = ["rm", "-f"].concat(paths.map(p => String(p)));
        remover.running = false;
        remover.running = true;
    }

    function _keep(next) {
        root._forget(ClipboardHistory.clipboardOrphans(root.ownEntries, next));
        root.ownEntries = next;
    }

    // Counts only: the contents are the user's, and IPC output ends up in
    // terminals and bug reports.
    function summary() {
        return {
            source: root.source,
            wanted: root.wanted,
            klipperRunning: root.klipperPresent,
            count: root.entries.length,
            images: root.entries.filter(e => e.image).length,
            pinned: root.entries.filter(e => e.pinned).length
        };
    }

    function _checkKlipper() {
        owner.running = false;
        owner.running = true;
    }

    // Klipper's database first; its DBus list when that cannot be read.
    function _refresh() {
        if (!root.klipper)
            return;
        store.running = false;
        store.running = true;
    }

    function _refreshOverDbus() {
        history.running = false;
        history.running = true;
    }

    // What the database reader printed: "store" and then the rows as JSON
    // (nothing at all for an empty history), or nothing when it could not
    // read a database it knows.
    function _storeRead(output) {
        const text = String(output ?? "");
        if (!text.startsWith("store\n")) {
            root._refreshOverDbus();
            return;
        }
        let rows = [];
        try {
            const body = text.slice(6).trim();
            rows = body.length > 0 ? JSON.parse(body) : [];
        } catch (e) {
            Log.debug("clipboard", `Klipper's history unreadable: ${e}`);
            root._refreshOverDbus();
            return;
        }
        root.klipperEntries = ClipboardHistory.klipperStoreEntries(rows, `${Paths.klipperDir}/data`);
    }

    Component.onCompleted: {
        root._checkKlipper();
        // Off at start: there is nothing to read back, and nothing to wait for.
        if (!root.keepPins)
            root._pinsReadBack();
    }

    onKlipperChanged: root._refresh()
    onWantedChanged: root._refresh()

    readonly property Process _owner: Process {
        id: owner
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.DBus",
                  "--object-path", "/org/freedesktop/DBus",
                  "--method", "org.freedesktop.DBus.NameHasOwner", "org.kde.klipper"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.klipperPresent = this.text.indexOf("true") >= 0;
                root.checked = true;
            }
        }
    }

    // NameOwnerChanged for Klipper's name: it appeared or went away.
    readonly property DbusWatch _names: DbusWatch {
        service: "org.freedesktop.DBus"
        path: "/org/freedesktop/DBus"
        filter: "org.kde.klipper"
        onChanged: root._checkKlipper()
    }

    readonly property DbusWatch _updates: DbusWatch {
        service: "org.kde.klipper"
        path: "/klipper"
        filter: "clipboardHistoryUpdated"
        running: root.klipper
        onChanged: root._refresh()
    }

    // Klipper's history, read from its database without writing to it:
    // sqlite3 opens it read-only, and only a database that says it is
    // version 3 -- the one whose layout this knows -- is read at all. Text is
    // cut at 8 KB a row, as ours is.
    readonly property Process _store: Process {
        id: store
        command: ["sh", "-c",
                  'db="$1/history3.sqlite"; '
                  + '[ -r "$db" ] && command -v sqlite3 >/dev/null 2>&1 || exit 0; '
                  + '[ "$(sqlite3 -readonly "$db" "select db_version from version" 2>/dev/null)" = 3 ] || exit 0; '
                  + 'rows=$(sqlite3 -readonly -json "$db" "select m.uuid as uuid, substr(m.text, 1, 8192) as text, '
                  + 'm.starred as starred, coalesce(m.last_used_time, m.added_time) as used, a.data_uuid as image '
                  + 'from main m left join aux a on a.uuid = m.uuid and a.mimetype = \'image/png\' '
                  + 'order by used desc limit 200" 2>/dev/null) || exit 0; '
                  + 'printf "store\\n%s\\n" "$rows"',
                  "--", Paths.klipperDir]
        stdout: StdioCollector {
            onStreamFinished: root._storeRead(this.text)
        }
    }

    readonly property Process _history: Process {
        id: history
        command: Dbus.callArgs("org.kde.klipper", "/klipper", "org.kde.klipper.klipper", "getClipboardHistoryMenu")
        stdout: StdioCollector {
            onStreamFinished: {
                const reply = Dbus.unwrap(this.text, "getClipboardHistoryMenu");
                root.klipperEntries = ClipboardHistory.klipperEntries(Array.isArray(reply?.[0]) ? reply[0] : []);
            }
        }
    }

    // One JSON line per clipboard change, from a script run by wl-paste with
    // the new contents on its stdin. Anything offering KDE's password-manager
    // hint is skipped before it is read; text is cut at 8 KB, so a line is
    // bounded before it reaches JSON.parse.
    readonly property Process _watch: Process {
        running: root.checked && !root.klipper
        command: ["wl-paste", "--type", "text", "--watch", "sh", "-c",
                  'case "$(wl-paste --list-types 2>/dev/null)" in *x-kde-passwordManagerHint*) exit 0 ;; esac; '
                  + 'head -c 8192 | jq -cRs "{text: .}"']
        stdout: SplitParser {
            onRead: line => {
                if (line.length > 65536)
                    return;
                let text = "";
                try {
                    text = JSON.parse(line).text ?? "";
                } catch (e) {
                    return;
                }
                if (text.trim().length > 0)
                    root._keep(ClipboardHistory.clipboardAdd(root.ownEntries, text, root.limit, Date.now()));
            }
        }
    }

    // Images, watched apart from text. `wl-paste --watch` hands the contents
    // to a command on stdin, and the type has to be asked for: a watcher for
    // text/plain never fires for a picture, which is why a copied image used
    // to reach this history as nothing at all.
    //
    // The file is written by the shell script rather than carried through
    // JSON: a PNG is not text and there is no reason for the pixels to pass
    // through the QML engine at all. What comes back on stdout is one line
    // naming the file and its size.
    readonly property Process _watchImages: Process {
        running: root.checked && !root.klipper
        command: ["wl-paste", "--type", "image/png", "--watch", "sh", "-c",
                  'case "$(wl-paste --list-types 2>/dev/null)" in *x-kde-passwordManagerHint*) exit 0 ;; esac; '
                  + `mkdir -p '${root.imageDir}' || exit 0; `
                  + `f='${root.imageDir}'/$(date +%s%N).png; `
                  // Bounded: a screenshot of four monitors is large, and
                  // anything past the cap is not a picture worth keeping.
                  + 'head -c 33554432 > "$f" || exit 0; '
                  + '[ -s "$f" ] || { rm -f "$f"; exit 0; }; '
                  + 'size=$(identify -format "%w %h" "$f" 2>/dev/null || echo "0 0"); '
                  + 'printf \'{"path":"%s","width":%s,"height":%s}\\n\' "$f" ${size% *} ${size#* }']
        stdout: SplitParser {
            onRead: line => {
                let entry = null;
                try {
                    entry = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (!entry?.path)
                    return;
                const now = Date.now();
                const repick = root._picked.length > 0 && now - root._pickedAt < 5000;
                const old = root._picked;
                root._picked = "";
                root._keep(repick
                    ? ClipboardHistory.clipboardReplaceImage(root.ownEntries, old, entry.path, entry.width,
                                                             entry.height, root.limit, now)
                    : ClipboardHistory.clipboardAddImage(root.ownEntries, entry.path, entry.width,
                                                         entry.height, root.limit, now));
            }
        }
    }

    readonly property Process _remove: Process { id: remover }

    // ---- pins across a restart ----------------------------------------------

    // Whether pinned entries are written down and read back at start.
    readonly property bool keepPins: ConfigStore.value("clipboard.keepPins", true) !== false

    // What was last written, so the file is touched only when the pins
    // change, not on every copy. Empty until the file has been read: nothing
    // is written over the pins before they are back.
    property string _pinsWritten: ""
    property bool _pinsRead: false

    onOwnEntriesChanged: root._savePins()
    onKeepPinsChanged: root.keepPins ? root._savePins() : root._dropPins()

    function _savePins() {
        if (!root.keepPins || !root._pinsRead)
            return;
        const json = JSON.stringify(ClipboardHistory.clipboardPinsToKeep(root.ownEntries));
        if (json === root._pinsWritten)
            return;
        root._pinsWritten = json;
        root._pinsPending = json;
        pinWriter.running = false;
        pinWriter.stdinEnabled = true;
        pinWriter.running = true;
    }

    // Off: the file goes, and nothing is left on disk to say what was pinned.
    // The pins themselves stay for as long as the shell runs.
    function _dropPins() {
        root._pinsWritten = "";
        pinRemover.running = false;
        pinRemover.running = true;
    }

    property string _pinsPending: ""

    // The pins are back (or there were none to read): saving may begin, and
    // what an earlier run left can be told apart from what is kept.
    function _pinsReadBack() {
        root._pinsRead = true;
        root._sweep();
    }

    // ---- what an earlier run left -------------------------------------------

    // When this run began, in nanoseconds as the watcher names its files.
    readonly property string _startedAt: `${Date.now()}000000`
    property bool _swept: false

    // Once a run: list the folder, then delete what is stale in it.
    function _sweep() {
        if (root._swept)
            return;
        root._swept = true;
        sweepList.running = true;
    }

    function _sweepFound(names) {
        const stale = ClipboardHistory.clipboardStale(names, root.imageDir, root.ownEntries, root._startedAt);
        if (stale.length === 0)
            return;
        Log.info("clipboard", `deleting ${stale.length} image file(s) an earlier run left`);
        sweeper.command = ["rm", "-f", "--"].concat(stale);
        sweeper.running = true;
    }

    // The file names alone, of the folder's own files: no subfolders, and a
    // link is not followed. A folder that is not there yet lists nothing.
    readonly property Process _sweepList: Process {
        id: sweepList
        command: ["find", root.imageDir, "-maxdepth", "1", "-type", "f", "-name", "*.png", "-printf", "%f\n"]
        stdout: StdioCollector {
            onStreamFinished: root._sweepFound(this.text.split("\n").filter(n => n.length > 0))
        }
    }

    // Its own process: the remover is restarted on every trim of the
    // history, which would cut a long sweep short.
    readonly property Process _sweeper: Process { id: sweeper }

    // Written through a shell rather than FileView: umask 077 makes the file
    // the user's alone, and the rename means a half-written file is never
    // what is read back.
    readonly property Process _pinWriter: Process {
        id: pinWriter
        command: ["sh", "-c", 'umask 077; mkdir -p "$(dirname "$1")" && cat > "$1.tmp" && mv -f "$1.tmp" "$1"',
                  "--", Paths.clipboardPinsFile]
        stdinEnabled: true
        onStarted: {
            pinWriter.write(root._pinsPending);
            root._pinsPending = "";
            pinWriter.stdinEnabled = false;
        }
    }

    readonly property Process _pinRemover: Process {
        id: pinRemover
        command: ["rm", "-f", "--", Paths.clipboardPinsFile]
    }

    readonly property FileView _pinsFile: FileView {
        path: root.keepPins ? Paths.clipboardPinsFile : ""
        printErrors: false

        onLoaded: {
            if (root._pinsRead)
                return;
            let saved = [];
            try {
                saved = JSON.parse(text());
            } catch (e) {
                Log.debug("clipboard", `pins unreadable: ${e}`);
            }
            root.ownEntries = ClipboardHistory.clipboardRestorePins(root.ownEntries, saved);
            root._pinsWritten = JSON.stringify(ClipboardHistory.clipboardPinsToKeep(root.ownEntries));
            root._pinsReadBack();
        }

        // No file: nothing was pinned yet. Saving may begin.
        onLoadFailed: {
            root._pinsReadBack();
            root._savePins();
        }
    }
}
