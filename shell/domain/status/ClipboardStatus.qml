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
    // this shell -- and Klipper's DBus interface can hand out its text and
    // nothing else: an image in its history can be seen and never chosen.
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
            if (!entry.path || root.klipper)
                return;
            root._picked = entry.path;
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

    // Whether choosing this entry would do anything. An image in Klipper's
    // history is Klipper's file, not ours, and its DBus interface offers no
    // way to select one -- so it is shown and said to be Plasma's.
    function pickable(entry) {
        return !!entry && (entry.image ? (!root.klipper && !!entry.path) : String(entry.text ?? "").length > 0);
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

    function _refresh() {
        if (!root.klipper)
            return;
        history.running = false;
        history.running = true;
    }

    Component.onCompleted: {
        root._checkKlipper();
        // Off at start: there is nothing to read back, and nothing to wait for.
        if (!root.keepPins)
            root._pinsRead = true;
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
            root._pinsRead = true;
        }

        // No file: nothing was pinned yet. Saving may begin.
        onLoadFailed: {
            root._pinsRead = true;
            root._savePins();
        }
    }
}
