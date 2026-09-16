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
// Choosing an entry puts it on the clipboard with wl-copy, through stdin, in
// both cases: Klipper sees the change and moves the entry to the top, and the
// text is never in a process's arguments, where any local user could read it
// from /proc.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.kde
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

    // [{ text, image }], newest first.
    readonly property var entries: root.klipper ? root.klipperEntries : root.ownEntries

    // Put an entry back on the clipboard. Text goes through stdin, so it is
    // never in a process's arguments where any local user could read it from
    // /proc; an image is a file, and wl-copy reads it the same way.
    function pick(entry) {
        if (!entry)
            return;
        if (entry.image) {
            if (!entry.path || root.klipper)
                return;
            copyImage.command = ["sh", "-c", 'wl-copy --type image/png < "$1"', "--", String(entry.path)];
            copyImage.running = false;
            copyImage.running = true;
            return;
        }
        if (!entry.text)
            return;
        root._pending = entry.text;
        copy.stdinEnabled = true;
        copy.running = true;
    }

    // Whether choosing this entry would do anything. An image in Klipper's
    // history is Klipper's file, not ours, and its DBus interface offers no
    // way to select one -- so it is shown and said to be Plasma's.
    function pickable(entry) {
        return !!entry && (entry.image ? (!root.klipper && !!entry.path) : String(entry.text ?? "").length > 0);
    }

    function clear() {
        if (root.klipper) {
            clearKlipper.running = false;
            clearKlipper.running = true;
        } else {
            root._forget(StatusIcons.clipboardOrphans(root.ownEntries, []));
            root.ownEntries = [];
        }
    }

    // The files of entries that have fallen out of the history. Deleted with
    // `rm -f` on exactly the paths this shell wrote, never a directory and
    // never a pattern.
    function _forget(paths) {
        if (!paths || paths.length === 0)
            return;
        remove.command = ["rm", "-f"].concat(paths.map(p => String(p)));
        remove.running = false;
        remove.running = true;
    }

    function _keep(next) {
        root._forget(StatusIcons.clipboardOrphans(root.ownEntries, next));
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
            images: root.entries.filter(e => e.image).length
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

    property string _pending: ""

    Component.onCompleted: root._checkKlipper()

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
        command: ["busctl", "--user", "--json=short", "call", "org.kde.klipper", "/klipper",
                  "org.kde.klipper.klipper", "getClipboardHistoryMenu"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.klipperEntries = StatusIcons.klipperEntries(JSON.parse(this.text).data[0]);
                } catch (e) {
                    root.klipperEntries = [];
                }
            }
        }
    }

    readonly property Process _clearKlipper: Process {
        id: clearKlipper
        command: ["busctl", "--user", "call", "org.kde.klipper", "/klipper",
                  "org.kde.klipper.klipper", "clearClipboardHistory"]
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
                    root._keep(StatusIcons.clipboardAdd(root.ownEntries, text, root.limit));
            }
        }
    }

    readonly property Process _copy: Process {
        id: copy
        command: ["wl-copy"]
        stdinEnabled: true
        onStarted: {
            copy.write(root._pending);
            root._pending = "";
            copy.stdinEnabled = false;
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
                root._keep(StatusIcons.clipboardAddImage(root.ownEntries, entry.path,
                                                         entry.width, entry.height, root.limit));
            }
        }
    }

    readonly property Process _copyImage: Process { id: copyImage }

    readonly property Process _remove: Process { id: remove }
}
