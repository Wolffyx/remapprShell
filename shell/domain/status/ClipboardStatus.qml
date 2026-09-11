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
// history of its own from `wl-paste --watch`: text only, in memory only,
// never written anywhere, and never anything a password manager marks secret.
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
import qs.platform.kde
import qs.domain.status.icons

QtObject {
    id: root

    // How much of our own history is kept. Klipper keeps its own count.
    readonly property int limit: 50

    // Whether Klipper is on the bus. Checked at start and whenever the name
    // changes hands, which is what a renderer switch does.
    property bool klipper: false
    property bool checked: false

    readonly property string source: root.klipper ? "klipper" : "own"

    property var klipperEntries: []
    property var ownEntries: []

    // [{ text, image }], newest first.
    readonly property var entries: root.klipper ? root.klipperEntries : root.ownEntries

    function pick(entry) {
        if (!entry || entry.image || !entry.text)
            return;
        root._pending = entry.text;
        copy.stdinEnabled = true;
        copy.running = true;
    }

    function clear() {
        if (root.klipper) {
            clearKlipper.running = false;
            clearKlipper.running = true;
        } else {
            root.ownEntries = [];
        }
    }

    // Counts only: the contents are the user's, and IPC output ends up in
    // terminals and bug reports.
    function summary() {
        return {
            source: root.source,
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

    readonly property Process _owner: Process {
        id: owner
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.DBus",
                  "--object-path", "/org/freedesktop/DBus",
                  "--method", "org.freedesktop.DBus.NameHasOwner", "org.kde.klipper"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.klipper = this.text.indexOf("true") >= 0;
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
                    root.ownEntries = StatusIcons.clipboardAdd(root.ownEntries, text, root.limit);
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
}
